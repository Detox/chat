/**
 * @package Detox chat
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
const COMMAND_DIRECT_CONNECTION_SDP	= 0
const COMMAND_SECRET_UPDATE			= 1
const COMMAND_NICKNAME				= 2
const COMMAND_TEXT_MESSAGE			= 3
const COMMAND_TEXT_MESSAGE_RECEIVED	= 4

# TODO: Separate set of commands for direct connections (chat, file transfers, calls, etc.)

function Wrapper (detox-core, detox-crypto, detox-utils, fixed-size-multiplexer, async-eventer)
	string2array		= detox-utils['string2array']
	are_arrays_equal	= detox-utils['are_arrays_equal']
	ArraySet			= detox-utils['ArraySet']

	const APPLICATION	= string2array('detox-chat-v0')
	/**
	 * @constructor
	 *
	 * @param {!Object}		core_instance					Detox core instance
	 * @param {Uint8Array=}	real_key_seed					Seed used to generate real long-term keypair (if not specified - random one is used)
	 * @param {string=}		nickname						User nickname that will be shown to the friend
	 * @param {number=}		number_of_introduction_nodes	Number of introduction nodes used for announcement to the network
	 * @param {number=}		number_of_intermediate_nodes	How many hops should be made when making connections
	 *
	 * @return {!Chat}
	 */
	!function Chat (core_instance, real_key_seed = null, name = '', number_of_introduction_nodes = 3, number_of_intermediate_nodes = 3)
		if !(@ instanceof Chat)
			return new Chat(core_instance, real_key_seed, name, number_of_introduction_nodes, number_of_intermediate_nodes)
		async-eventer.call(@)

		@_core_instance					= core_instance
		@_real_key_seed					= real_key_seed || detox-core['generate_seed']()
		@_real_keypair					= detox-core['create_keypair'](@_real_key_seed)
		@_nickname						= string2array(nickname)
		@_number_of_introduction_nodes	= number_of_introduction_nodes
		@_number_of_intermediate_nodes	= number_of_intermediate_nodes

		@_connected_nodes				= ArraySet()

		@_core_instance
			.'once'('announced', (real_public_key) !~>
				if !@_is_current_chat(real_public_key)
					return
				@'fire'('announced')
			)
			.'on'('connected', (real_public_key, friend_id) !~>
				if !@_is_current_chat(real_public_key)
					return
				@_connected_nodes.add(friend_id)
				@'fire'('connected', friend_id)
			)
			.'on'('connection_progress', (real_public_key, friend_id, stage) !~>
				if !@_is_current_chat(real_public_key)
					return
				@'fire'('connection_progress', friend_id, stage)
			)
			.'on'('connection_failed', (real_public_key, friend_id, reason) !~>
				if !@_is_current_chat(real_public_key)
					return
				@'fire'('connection_failed', friend_id, reason)
			)
			.'on'('disconnected', (real_public_key, friend_id) !~>
				if !@_is_current_chat(real_public_key)
					return
				@_connected_nodes.delete(friend_id)
				@'fire'('disconnected', friend_id)
			)
			.'on'('introduction', (data) !~>
				if !(
					@_is_current_chat(real_public_key) &&
					are_arrays_equal(APPLICATION, data['application'].subarray(0, APPLICATION.length))
				)
					return
				@'fire'('introduction', data['target_id'], data['secret'])
					.then !~>
						data['number_of_intermediate_nodes']	= Math.max(@_number_of_intermediate_nodes - 1, 1)
			)
			.'on'('data', (real_public_key, friend_id, received_command, received_data) !~>
				if !@_is_current_chat(real_public_key)
					return
				#TODO
			)
		# TODO

	Cache.'CONNECTION_ERROR_CANT_FIND_INTRODUCTION_NODES'		= detox-core['CONNECTION_ERROR_CANT_FIND_INTRODUCTION_NODES']
	Cache.'CONNECTION_ERROR_NOT_ENOUGH_INTERMEDIATE_NODES'		= detox-core['CONNECTION_ERROR_NOT_ENOUGH_INTERMEDIATE_NODES']
	Cache.'CONNECTION_ERROR_NO_INTRODUCTION_NODES'				= detox-core['CONNECTION_ERROR_NO_INTRODUCTION_NODES']
	Cache.'CONNECTION_ERROR_CANT_CONNECT_TO_RENDEZVOUS_POINT'	= detox-core['CONNECTION_ERROR_CANT_CONNECT_TO_RENDEZVOUS_POINT']
	Cache.'CONNECTION_ERROR_OUT_OF_INTRODUCTION_NODES'			= detox-core['CONNECTION_ERROR_OUT_OF_INTRODUCTION_NODES']

	Cache.'CONNECTION_PROGRESS_CONNECTED_TO_RENDEZVOUS_NODE'	= detox-core['CONNECTION_PROGRESS_CONNECTED_TO_RENDEZVOUS_NODE']
	Cache.'CONNECTION_PROGRESS_FOUND_INTRODUCTION_NODES'		= detox-core['CONNECTION_PROGRESS_FOUND_INTRODUCTION_NODES']
	Cache.'CONNECTION_PROGRESS_INTRODUCTION_SENT'				= detox-core['CONNECTION_PROGRESS_INTRODUCTION_SENT']

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
		'send_to' : (friend_id) !->
			# TODO
		# TODO: The rest of methods
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
			are_arrays_equal(@_real_keypair['ed25519']['public'], real_public_key)

	Chat:: = Object.assign(Object.create(async-eventer::), Chat::)

	Object.defineProperty(Chat::, 'constructor', {enumerable: false, value: Chat})
	{
		'ready'	: (callback) !->
			wait_for	= 2
			!function ready
				--wait_for
				if !wait_for
					callback()
			detox-core['ready'](ready)
			detox-crypto['ready'](ready)
		'Chat'	: Chat
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
