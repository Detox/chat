/**
 * @package Detox chat
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
function Wrapper (detox-core, detox-crypto, fixed-size-multiplexer, async-eventer)
	/**
	 * @constructor
	 *
	 * @param {!Object}	core_instance	Detox core instance
	 *
	 * @return {!Chat}
	 */
	!function Chat (core_instance)
		if !(@ instanceof Chat)
			return new Chat(core_instance)
		async-eventer.call(@)

		# TODO

	#Chat:: =
		#TODO

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
