/**
 * @package Detox chat
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
# detox-chat-v0
const APPLICATION			= Uint8Array.of(100, 101, 116, 111, 120, 45, 99, 104, 97, 116, 45, 118, 48)
const APPLICATION_STRING	= APPLICATION.join(',')

/**
 * @param {string}		string
 * @param {!Uint8Array}	array
 *
 * @return {boolean}
 */
function is_string_equal_to_array (string, array)
	string == array.join(',')

function Wrapper (detox-core, detox-crypto, fixed-size-multiplexer, async-eventer)
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
		@_real_key_seed					= real_key_seed || detox-core['generate_seed']()
		@_real_keypair					= detox-core['create_keypair'](@_real_key_seed)
		@_real_public_key_string		= @_real_keypair['ed25519']['public'].join(',')
		@_number_of_introduction_nodes	= number_of_introduction_nodes
		@_number_of_intermediate_nodes	= number_of_intermediate_nodes

		@_core_instance
			.'once'('announced', (real_public_key) !~>
				if !@_is_current_chat(real_public_key)
					return
				@'fire'('announced')
			)
			.'on'('connected', (real_public_key, target_id) !~>
				if !@_is_current_chat(real_public_key)
					return
				@'fire'('connected', target_id)
			)
			.'on'('connection_progress', (real_public_key, target_id, stage) !~>
				if !@_is_current_chat(real_public_key)
					return
				@'fire'('connection_progress', target_id, stage)
			)
			.'on'('connection_failed', (real_public_key, target_id, reason) !~>
				if !@_is_current_chat(real_public_key)
					return
				@'fire'('connection_failed', target_id, reason)
			)
			.'on'('disconnected', (real_public_key, target_id) !~>
				if !@_is_current_chat(real_public_key)
					return
				@'fire'('disconnected', target_id)
			)
			.'on'('introduction', (data) !~>
				if !(
					@_is_current_chat(real_public_key) &&
					is_string_equal_to_array(APPLICATION_STRING, data['application'].subarray(0, APPLICATION.length))
				)
					return
				@'fire'('introduction', data['target_id'], data['secret'])
					.then !~>
						data['number_of_intermediate_nodes']	= Math.max(@_number_of_intermediate_nodes - 1, 1)
			)
			.'on'('data', (real_public_key, target_id, received_command, received_data) !~>
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
			if @_destroyed
				return
			@_core_instance['connect_to'](
				@_real_key_seed
				friend_id
				APPLICATION
				secret
				@_number_of_intermediate_nodes
			)
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
			is_string_equal_to_array(@_real_public_key_string, real_public_key)

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
	define(['@detox/core', '@detox/crypto', 'fixed-size-multiplexer', 'async-eventer'], Wrapper)
else if typeof exports == 'object'
	# CommonJS
	module.exports = Wrapper(require('@detox/core'), require('@detox/crypto'), require('fixed-size-multiplexer'), require('async-eventer'))
else
	# Browser globals
	@'detox_chat' = Wrapper(@'detox_core', @'detox_crypto', @'fixed_size_multiplexer', @'async_eventer')
