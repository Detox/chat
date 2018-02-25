/**
 * @package Detox chat
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
const COMMAND_DIRECT_CONNECTION_SDP	= 0
const COMMAND_SECRET				= 1
const COMMAND_NICKNAME				= 2
const COMMAND_TEXT_MESSAGE			= 3
const COMMAND_RECEIVED				= 4
const CUSTOM_COMMANDS_OFFSET		= 32 # 5..31 are also reserved for future use, everything above is available for the user

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

function Wrapper (detox-core, detox-crypto, detox-utils, fixed-size-multiplexer, async-eventer)
	random_bytes		= detox-utils['random_bytes']
	string2array		= detox-utils['string2array']
	array2string		= detox-utils['array2string']
	are_arrays_equal	= detox-utils['are_arrays_equal']
	concat_arrays		= detox-utils['concat_arrays']
	error_handler		= detox-utils['error_handler']
	ArraySet			= detox-utils['ArraySet']

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

		@_connected_nodes				= ArraySet()
		@_last_sent_date				= 0

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
				@'fire'('disconnected', friend_id)
			)
			.'on'('introduction', (data) ~>
				if !(
					!@_destroyed &&
					@_is_current_chat(data['real_public_key']) &&
					are_arrays_equal(APPLICATION, data['application'].subarray(0, APPLICATION.length))
				)
					return
				@'fire'('introduction', data['target_id'], data['secret'], data['application'])
					.then !~>
						data['number_of_intermediate_nodes']	= Math.max(@_number_of_intermediate_nodes - 1, 1)
					.catch (error) !~>
						error_handler(error)
			)
			.'on'('data', (real_public_key, friend_id, received_command, received_data) !~>
				if @_destroyed || !@_is_current_chat(real_public_key)
					return
				switch received_command
					case COMMAND_DIRECT_CONNECTION_SDP
						# TODO
						void
					case COMMAND_NICKNAME
						@'fire'('nickname', friend_id, array2string(received_data), received_data)
					case COMMAND_SECRET
						if received_data.length != ID_LENGTH
							return
						@'fire'('secret', friend_id, received_data)
					case COMMAND_TEXT_MESSAGE
						if received_data.length < 9 # Date + at least 1 character
							return
						date_array	= received_data.subarray(0, 8)
						date		= date_to_number(date_array)
						text_array	= received_data.subarray(8)
						@_send(friend_id, COMMAND_RECEIVED, date_array)
						@'fire'('text_message', friend_id, date, array2string(text_array), text_array)
					case COMMAND_RECEIVED
						@'fire'('received', friend_id, date_to_number(received_data))
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
		 * @param {!uint8Array} secret		Secret used for connection to a friend
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
			@_send(friend_id, COMMAND_SECRET, secret_to_send)
		/**
		 * Send a text message to a friend
		 *
		 * @param {!Uint8Array}			friend_id	Ed25519 public key of a friend
		 * @param {string|!Uint8Array}	text		Text message to be sent to a friend (max 65527 bytes)
		 *
		 * @return {number} Unix timestamp in milliseconds of the message (0 if message is empty or too big or connection is not present)
		 */
		'text_message' : (friend_id, text) ->
			if @_destroyed || !@_connected_nodes.has(friend_id)
				return 0
			if typeof text == 'string'
				text	= string2array(text)
			if !text.length
				return 0
			current_date	= +(new Date)
			if current_date <= @_last_sent_date
				current_date	= @_last_sent_date + 1
			data	= concat_arrays([date_to_array(current_date), text])
			if data.length > @_max_data_size
				return 0
			@_last_sent_date	= current_date
			@_send(friend_id, COMMAND_TEXT_MESSAGE, data)
			current_date
		/**
		 * Send custom command
		 *
		 * @param {!Uint8Array}	friend_id	Ed25519 public key of a friend
		 * @param {number}		command		Custom command beyond Detox chat spec to be interpreted by application, 0..223
		 * @param {!Uint8Array}	data		Data been sent alongside command
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
		 * @param {!Uint8Array}	friend_id
		 * @param {number}		command
		 * @param {!Uint8Array}	data
		 */
		_send : (friend_id, command, data) !->
			@_core_instance['send_to'](@_real_public_key, friend_id, command, data)

	Chat:: = Object.assign(Object.create(async-eventer::), Chat::)

	Object.defineProperty(Chat::, 'constructor', {enumerable: false, value: Chat})
	{
		'ready'				: (callback) !->
			wait_for	= 2
			!function ready
				--wait_for
				if !wait_for
					callback()
			detox-core['ready'](ready)
			detox-crypto['ready'](ready)
		'Chat'				: Chat
		/**
		 * Generates random seed that can be used as keypair seed
		 *
		 * @return {!Uint8Array} 32 bytes
		 */
		'generate_seed'		: ->
			random_bytes(ID_LENGTH)
		/**
		 * Generates random secret that can be used for friends connections
		 *
		 * @return {!Uint8Array} 32 bytes
		 */
		'generate_secret'	: ->
			random_bytes(ID_LENGTH)
	}

if typeof define == 'function' && define['amd']
	# AMD
	define(['@detox/core', '@detox/crypto', '@detox/utils', 'fixed-size-multiplexer', 'async-eventer'], Wrapper)
else if typeof exports == 'object'
	# CommonJS
	module.exports = Wrapper(require('@detox/core'), require('@detox/crypto'), require('@detox/utils'), require('fixed-size-multiplexer'), require('async-eventer'))
else
	# Browser globals
	@'detox_chat' = Wrapper(@'detox_core', @'detox_crypto', @'detox_utils', @'fixed_size_multiplexer', @'async_eventer')
