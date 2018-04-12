/**
 * @package Detox chat
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
/*
 * Implements version 0.2.0 of the specification
 */
const COMMAND_DIRECT_CONNECTION_SDP	= 0
const COMMAND_SECRET				= 1
const COMMAND_SECRET_RECEIVED		= 2
const COMMAND_NICKNAME				= 3
const COMMAND_TEXT_MESSAGE			= 4
const COMMAND_TEXT_MESSAGE_RECEIVED	= 5
const CUSTOM_COMMANDS_OFFSET		= 64 # 6..63 are also reserved for future use, everything above is available for the user

# TODO: Separate set of commands for direct connections (chat, file transfers, calls, etc.)

const ID_LENGTH	= 32

/**
 * @param {!Uint8Array} array
 *
 * @return {number}
 */
function date_to_number (array)
	view	= new DataView(array.buffer, array.byteOffset, array.byteLength)
	view.getFloat64(0, false)

/**
 * @param {number} number
 *
 * @return {!Uint8Array}
 */
function date_to_array (number)
	array	= new Uint8Array(8)
	view	= new DataView(array.buffer)
	view.setFloat64(0, number, false)
	array

function Wrapper (detox-core, detox-crypto, detox-utils, async-eventer)
	random_bytes		= detox-utils['random_bytes']
	string2array		= detox-utils['string2array']
	array2string		= detox-utils['array2string']
	hex2array			= detox-utils['hex2array']
	array2hex			= detox-utils['array2hex']
	are_arrays_equal	= detox-utils['are_arrays_equal']
	concat_arrays		= detox-utils['concat_arrays']
	error_handler		= detox-utils['error_handler']
	ArraySet			= detox-utils['ArraySet']
	base58_encode		= detox-utils['base58_encode']
	base58_decode		= detox-utils['base58_decode']
	blake2b_256			= detox-crypto['blake2b_256']

	const APPLICATION	= string2array('detox-chat-v0')
	/**
	 * @constructor
	 *
	 * @param {!Object}		core_instance					Detox core instance
	 * @param {Uint8Array=}	real_key_seed					Seed used to generate real long-term keypair (if not specified - random one is used)
	 * @param {number=}		number_of_introduction_nodes	Number of introduction nodes used for announcement to the network
	 * @param {number=}		number_of_intermediate_nodes	How many hops should be made when making connections
	 *
	 * @return {!Chat}
	 */
	!function Chat (core_instance, real_key_seed = null, number_of_introduction_nodes = 3, number_of_intermediate_nodes = 3)
		if !(@ instanceof Chat)
			return new Chat(core_instance, real_key_seed, number_of_introduction_nodes, number_of_intermediate_nodes)
		async-eventer.call(@)

		@_core_instance					= core_instance
		@_real_key_seed					= real_key_seed || random_bytes(ID_LENGTH)
		@_real_keypair					= detox-crypto['create_keypair'](@_real_key_seed)
		@_real_public_key				= @_real_keypair['ed25519']['public']
		@_number_of_introduction_nodes	= number_of_introduction_nodes
		@_number_of_intermediate_nodes	= number_of_intermediate_nodes
		@_max_data_size					= @_core_instance['get_max_data_size']()

		@_connected_nodes					= ArraySet()
		@_connection_secret_updated_local	= ArraySet()
		@_connection_secret_updated_remote	= ArraySet()
		@_last_date_sent					= 0

		@_core_instance
			.'once'('announced', (real_public_key) !~>
				if @_destroyed || !@_is_current_chat(real_public_key)
					return
				@'fire'('announced')
			)
			.'on'('connected', (real_public_key, friend_id) !~>
				if @_destroyed || !@_is_current_chat(real_public_key)
					return
				@_connected_nodes.add(friend_id)
				@'fire'('connected', friend_id)
			)
			.'on'('connection_progress', (real_public_key, friend_id, stage) !~>
				if @_destroyed || !@_is_current_chat(real_public_key)
					return
				@'fire'('connection_progress', friend_id, stage)
			)
			.'on'('connection_failed', (real_public_key, friend_id, reason) !~>
				if @_destroyed || !@_is_current_chat(real_public_key)
					return
				@'fire'('connection_failed', friend_id, reason)
			)
			.'on'('disconnected', (real_public_key, friend_id) !~>
				if @_destroyed || !@_is_current_chat(real_public_key)
					return
				@_connected_nodes.delete(friend_id)
				@_connection_secret_updated_local.delete(friend_id)
				@_connection_secret_updated_remote.delete(friend_id)
				@'fire'('disconnected', friend_id)
			)
			.'on'('introduction', (data) ~>
				if !(
					!@_destroyed &&
					@_is_current_chat(data['real_public_key']) &&
					are_arrays_equal(APPLICATION, data['application'].subarray(0, APPLICATION.length))
				)
					return
				@'fire'('introduction', data['target_id'], data['secret'], data['application']).then !~>
					data['number_of_intermediate_nodes']	= Math.max(@_number_of_intermediate_nodes - 1, 1)
			)
			.'on'('data', (real_public_key, friend_id, received_command, received_data) !~>
				if @_destroyed || !@_is_current_chat(real_public_key)
					return
				# We reject all other commands until secrets were updated on both sides
				if !(
					received_command in [COMMAND_SECRET, COMMAND_SECRET_RECEIVED] ||
					@_secrets_updated(friend_id)
				)
					return
				switch received_command
					case COMMAND_DIRECT_CONNECTION_SDP
						# TODO
						void
					case COMMAND_SECRET
						if received_data.length != ID_LENGTH
							return
						# Application can reject to accept updated secret if it was used before already or for some other reason
						@'fire'('secret', friend_id, received_data)
							.then !~>
								@_connection_secret_updated_remote.add(friend_id)
								@_send(friend_id, COMMAND_SECRET_RECEIVED, new Uint8Array(0))
							.catch(error_handler)
					case COMMAND_SECRET_RECEIVED
						if !@_connection_secret_updated_local.has(friend_id)
							return
						@'fire'('secret_received', friend_id)
					case COMMAND_NICKNAME
						@'fire'('nickname', friend_id, array2string(received_data), received_data)
					case COMMAND_TEXT_MESSAGE
						if received_data.length < 9 # Date + at least 1 character
							return
						date_sent_array		= received_data.subarray(0, 8)
						date_sent			= date_to_number(date_sent_array)
						date_written_array	= received_data.subarray(8, 16)
						date_written		= date_to_number(date_written_array)
						text_array			= received_data.subarray(16)
						@_send(friend_id, COMMAND_TEXT_MESSAGE_RECEIVED, date_sent_array)
						@'fire'('text_message', friend_id, date_sent, date_written, array2string(text_array), text_array)
					case COMMAND_TEXT_MESSAGE_RECEIVED
						@'fire'('text_message_received', friend_id, date_to_number(received_data))
					else
						if received_command < CUSTOM_COMMANDS_OFFSET
							return
						@'fire'('custom_command', friend_id, received_command - CUSTOM_COMMANDS_OFFSET, received_data)
			)

	Chat.'CONNECTION_ERROR_CANT_FIND_INTRODUCTION_NODES'		= detox-core['CONNECTION_ERROR_CANT_FIND_INTRODUCTION_NODES']
	Chat.'CONNECTION_ERROR_NOT_ENOUGH_INTERMEDIATE_NODES'		= detox-core['CONNECTION_ERROR_NOT_ENOUGH_INTERMEDIATE_NODES']
	Chat.'CONNECTION_ERROR_NO_INTRODUCTION_NODES'				= detox-core['CONNECTION_ERROR_NO_INTRODUCTION_NODES']
	Chat.'CONNECTION_ERROR_CANT_CONNECT_TO_RENDEZVOUS_POINT'	= detox-core['CONNECTION_ERROR_CANT_CONNECT_TO_RENDEZVOUS_POINT']
	Chat.'CONNECTION_ERROR_OUT_OF_INTRODUCTION_NODES'			= detox-core['CONNECTION_ERROR_OUT_OF_INTRODUCTION_NODES']

	Chat.'CONNECTION_PROGRESS_CONNECTED_TO_RENDEZVOUS_NODE'		= detox-core['CONNECTION_PROGRESS_CONNECTED_TO_RENDEZVOUS_NODE']
	Chat.'CONNECTION_PROGRESS_FOUND_INTRODUCTION_NODES'			= detox-core['CONNECTION_PROGRESS_FOUND_INTRODUCTION_NODES']
	Chat.'CONNECTION_PROGRESS_INTRODUCTION_SENT'				= detox-core['CONNECTION_PROGRESS_INTRODUCTION_SENT']

	Chat:: =
		/**
		 * Announce itself to the network (can operate without announcement)
		 */
		'announce' : !->
			if @_announced || @_destroyed
				return
			@_announced	= true
			@_core_instance['announce'](
				@_real_key_seed
				@_number_of_introduction_nodes
				Math.max(@_number_of_intermediate_nodes - 1, 1)
			)
		/**
		 * Establish connection with a friend
		 *
		 * @param {!Uint8Array} friend_id	Ed25519 public key of a friend
		 * @param {!Uint8Array} secret		Secret used for connection to a friend
		 */
		'connect_to' : (friend_id, secret) !->
			if @_destroyed || @_connected_nodes.has(friend_id)
				return
			@_core_instance['connect_to'](
				@_real_key_seed
				friend_id
				APPLICATION
				secret
				@_number_of_intermediate_nodes
			)
		/**
		 * Send a nickname to a friend
		 *
		 * @param {!Uint8Array}			friend_id	Ed25519 public key of a friend
		 * @param {string|!Uint8Array}	nickname	Nickname as string or Uint8Array to be sent to a friend
		 */
		'nickname' : (friend_id, nickname) !->
			if @_destroyed || !@_connected_nodes.has(friend_id)
				return
			if typeof nickname == 'string'
				nickname	= string2array(nickname)
			@_send(friend_id, COMMAND_NICKNAME, nickname)
		/**
		 * Send a secret to a friend that will be used for future connections
		 *
		 * @param {!Uint8Array} friend_id	Ed25519 public key of a friend
		 * @param {!Uint8Array} secret		Personal secret to be used by a friend for future connection
		 */
		'secret' : (friend_id, secret) !->
			if @_destroyed || !@_connected_nodes.has(friend_id)
				return
			secret_to_send	= new Uint8Array(ID_LENGTH)
				..set(secret)
			@_connection_secret_updated_local.add(friend_id)
			@_send(friend_id, COMMAND_SECRET, secret_to_send)
		/**
		 * Send a text message to a friend
		 *
		 * @param {!Uint8Array}			friend_id		Ed25519 public key of a friend
		 * @param {number}				date_written	Unix timestamp in milliseconds when message was written
		 * @param {string|!Uint8Array}	text			Text message to be sent to a friend (max 65519 bytes)
		 *
		 * @return {number} Unix timestamp in milliseconds when the message was sent (0 if message is empty or too big or connection is not present)
		 */
		'text_message' : (friend_id, date_written, text) ->
			if @_destroyed || !@_connected_nodes.has(friend_id)
				return 0
			if typeof text == 'string'
				text	= string2array(text)
			if !text.length
				return 0
			date_sent	= +(new Date)
			if date_sent <= @_last_date_sent
				date_sent	= @_last_date_sent + 1
			data	= concat_arrays([date_to_array(date_sent), date_to_array(date_written), text])
			if data.length > @_max_data_size
				return 0
			@_last_date_sent	= date_sent
			@_send(friend_id, COMMAND_TEXT_MESSAGE, data)
			date_sent
		/**
		 * Send custom command
		 *
		 * @param {!Uint8Array}	friend_id	Ed25519 public key of a friend
		 * @param {number}		command		Custom command beyond Detox chat spec to be interpreted by application, 0..223
		 * @param {!Uint8Array}	data		Data been sent alongside command (max 65535 bytes)
		 */
		'custom_command' : (friend_id, command, data) !->
			@_send(friend_id, command + CUSTOM_COMMANDS_OFFSET, data)
		/**
		 * Destroys chat instance
		 */
		'destroy' : !->
			if @_destroyed
				return
			@_destroyed	= true
		/**
		 * @param {!Uint8Array} real_public_key
		 *
		 * @return {boolean}
		 */
		_is_current_chat : (real_public_key) ->
			are_arrays_equal(@_real_public_key, real_public_key)
		/**
		 * @param {!Uint8Array} friend_id
		 *
		 * @return {boolean}
		 */
		_secrets_updated : (friend_id) ->
			@_connection_secret_updated_local.has(friend_id) && @_connection_secret_updated_remote.has(friend_id)
		/**
		 * @param {!Uint8Array}	friend_id
		 * @param {number}		command
		 * @param {!Uint8Array}	data
		 */
		_send : (friend_id, command, data) !->
			@_core_instance['send_to'](@_real_public_key, friend_id, command, data)

	Chat:: = Object.assign(Object.create(async-eventer::), Chat::)

	/**
	 * @param {!Uint8Array} payload
	 *
	 * @return {string}
	 */
	function base58_check_encode (payload)
		checksum	= blake2b_256(payload).subarray(0, 2)
		base58_encode(concat_arrays([payload, checksum]))
	/**
	 * @param {string} string
	 *
	 * @return {!Uint8Array}
	 *
	 * @throws {Error}
	 */
	function base58_check_decode (string)
		decoded_array	= base58_decode(string)
		payload			= decoded_array.subarray(0, -2)
		checksum		= decoded_array.subarray(-2)
		if !are_arrays_equal(blake2b_256(payload).subarray(0, 2), checksum)
			throw new Error('Checksum is not correct')
		payload
	/**
	 * Encodes public key and secret into base58 string with built-in checksum
	 *
	 * @param {!Uint8Array} public_key
	 * @param {!Uint8Array} secret
	 *
	 * @return {string}
	 */
	function id_encode (public_key, secret)
		base58_check_encode(
			concat_arrays([public_key, secret])
		)
	/**
	 * Decodes encoded public key and secret from base58 string and checks built-in checksum
	 *
	 * @param {string} string
	 *
	 * @return {!Array<!Uint8Array>} [public_key, secret]
	 *
	 * @throws {Error} When checksum or ID is not correct
	 */
	function id_decode (string)
		payload		= base58_check_decode(string)
		if payload.length < ID_LENGTH || payload.length > (ID_LENGTH * 2)
			throw new Error('Incorrect ID')
		public_key	= payload.subarray(0, ID_LENGTH)
		secret		= payload.subarray(ID_LENGTH)
		[public_key, secret]
	/**
	 * Encodes ID, host and port of bootstrap node into base58 string with built-in checksum
	 *
	 * @param {string} id
	 * @param {string} host
	 * @param {number} port
	 *
	 * @return {string}
	 */
	function bootstrap_node_encode (id, host, port)
		base58_check_encode(
			concat_arrays([
				hex2array(id)
				string2array(host)
				new Uint8Array(
					Uint16Array.of(port).buffer
				)
			])
		)
	/**
	 * Decodes encoded ID, host and port from base58 string and checks built-in checksum
	 *
	 * @param {string} string
	 *
	 * @return {!Array} [id, host, port]
	 *
	 * @throws {Error} When checksum or bootstrap node information is not correct
	 */
	function bootstrap_node_decode (string)
		payload	= base58_check_decode(string)
		if payload.length < (ID_LENGTH + 1 + 2) # ID + host + port
			throw new Error('Incorrect bootstrap node information')
		id		= array2hex(payload.subarray(0, ID_LENGTH))
		host	= array2string(payload.subarray(ID_LENGTH, -2))
		port	= (
			new Uint16Array(payload.slice(-2).buffer)
		)[0]
		[id, host, port]

	Object.defineProperty(Chat::, 'constructor', {value: Chat})
	{
		'ready'					: (callback) !->
			<-! detox-core['ready']
			<-! detox-crypto['ready']
			callback()
		'Chat'					: Chat
		/**
		 * Generates random seed that can be used as keypair seed
		 *
		 * @return {!Uint8Array} 32 bytes
		 */
		'generate_seed'			: ->
			random_bytes(ID_LENGTH)
		/**
		 * Generates random secret that can be used for friends connections
		 *
		 * @return {!Uint8Array} 32 bytes
		 */
		'generate_secret'		: ->
			random_bytes(ID_LENGTH)
		'id_encode'				: id_encode
		'id_decode'				: id_decode
		'bootstrap_node_encode' : bootstrap_node_encode
		'bootstrap_node_decode' : bootstrap_node_decode
	}

if typeof define == 'function' && define['amd']
	# AMD
	define(['@detox/core', '@detox/crypto', '@detox/utils', 'async-eventer'], Wrapper)
else if typeof exports == 'object'
	# CommonJS
	module.exports = Wrapper(require('@detox/core'), require('@detox/crypto'), require('@detox/utils'), require('async-eventer'))
else
	# Browser globals
	@'detox_chat' = Wrapper(@'detox_core', @'detox_crypto', @'detox_utils', @'async_eventer')
