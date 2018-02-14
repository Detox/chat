// Generated by LiveScript 1.5.0
/**
 * @package Detox chat
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
(function(){
  function Wrapper(detoxCore, detoxCrypto, fixedSizeMultiplexer, asyncEventer){
    /**
     * @constructor
     *
     * @param {!Object}		core_instance	Detox core instance
     * @param {Uint8Array=}	real_key_seed	Seed used to generate real long-term keypair (if not specified - random one is used)
     *
     * @return {!Chat}
     */
    function Chat(core_instance, real_key_seed){
      real_key_seed == null && (real_key_seed = null);
      if (!(this instanceof Chat)) {
        return new Chat(core_instance, real_key_seed);
      }
      asyncEventer.call(this);
      this._core_instance = core_instance;
      this._real_key_seed = real_key_seed || detoxCore['generate_seed']();
    }
    Chat.prototype = {
      /**
       * Announce itself to the network (can operate without announcement)
       *
       * @param {number}	number_of_introduction_nodes
       * @param {number}	number_of_intermediate_nodes	How many hops should be made until introduction node (not including it)
       */
      'announce': function(number_of_introduction_nodes, number_of_intermediate_nodes){
        if (this._announced || this._destroyed) {
          return;
        }
        this._announced = true;
        this._core_instance['announce'](this._real_key_seed, number_of_introduction_nodes, number_of_intermediate_nodes);
      },
      'destroy': function(){
        if (this._destroyed) {
          return;
        }
        this._destroyed = true;
      }
    };
    Chat.prototype = Object.assign(Object.create(asyncEventer.prototype), Chat.prototype);
    Object.defineProperty(Chat.prototype, 'constructor', {
      enumerable: false,
      value: Chat
    });
    return {
      'ready': function(callback){
        var wait_for;
        wait_for = 2;
        function ready(){
          --wait_for;
          if (!wait_for) {
            callback();
          }
        }
        detoxCore['ready'](ready);
        detoxCrypto['ready'](ready);
      },
      'Chat': Chat
    };
  }
  if (typeof define === 'function' && define['amd']) {
    define(['@detox/core', '@detox/crypto', 'fixed-size-multiplexer', 'async-eventer'], Wrapper);
  } else if (typeof exports === 'object') {
    module.exports = Wrapper(require('@detox/core'), require('@detox/crypto'), require('fixed-size-multiplexer'), require('async-eventer'));
  } else {
    this['detox_chat'] = Wrapper(this['detox_core'], this['detox_crypto'], this['fixed_size_multiplexer'], this['async_eventer']);
  }
}).call(this);
