/**
 * @package Detox chat
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
function Wrapper (detox-core, detox-crypto, fixed-size-multiplexer, async-eventer)
	/**
	 * @constructor
	 *
	 * @param {!Object}		core_instance	Detox core instance
	 * @param {Uint8Array=}	real_key_seed	Seed used to generate real long-term keypair (if not specified - random one is used)
	 *
	 * @return {!Chat}
	 */
	!function Chat (core_instance, real_key_seed = null)
		if !(@ instanceof Chat)
			return new Chat(core_instance, real_key_seed)
		async-eventer.call(@)

		@_core_instance	= core_instance
		@_real_key_seed	= real_key_seed || detox-core['generate_seed']()

		# TODO

	Chat:: =
		/**
		 * Announce itself to the network (can operate without announcement)
		 *
		 * @param {number}	number_of_introduction_nodes
		 * @param {number}	number_of_intermediate_nodes	How many hops should be made until introduction node (not including it)
		 */
		'announce' : (number_of_introduction_nodes, number_of_intermediate_nodes) !->
			if @_announced || @_destroyed
				return
			@_announced	= true
			@_core_instance['announce'](@_real_key_seed, number_of_introduction_nodes, number_of_intermediate_nodes)
		# TODO: The rest of methods
		'destroy' : !->
			if @_destroyed
				return
			@_destroyed	= true

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
