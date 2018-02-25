// Generated by LiveScript 1.5.0
/**
 * @package Detox chat
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
(function(){
  var COMMAND_DIRECT_CONNECTION_SDP, COMMAND_SECRET, COMMAND_NICKNAME, COMMAND_TEXT_MESSAGE, COMMAND_RECEIVED, CUSTOM_COMMANDS_OFFSET, ID_LENGTH;
  COMMAND_DIRECT_CONNECTION_SDP = 0;
  COMMAND_SECRET = 1;
  COMMAND_NICKNAME = 2;
  COMMAND_TEXT_MESSAGE = 3;
  COMMAND_RECEIVED = 4;
  CUSTOM_COMMANDS_OFFSET = 32;
  ID_LENGTH = 32;
  /**
   * @param {!Uint8Array} array
   *
   * @return {number}
   */
  function date_to_number(array){
    var view;
    view = new DataView(array.buffer, array.byteOffset, array.byteLength);
    return view.getFloat64(0, false);
  }
  /**
   * @param {number} number
   *
   * @return {!Uint8Array}
   */
  function date_to_array(number){
    var array, view;
    array = new Uint8Array(8);
    view = new DataView(array.buffer);
    view.setFloat64(0, number, false);
    return array;
  }
  function Wrapper(detoxCore, detoxCrypto, detoxUtils, fixedSizeMultiplexer, asyncEventer){
    var random_bytes, string2array, array2string, are_arrays_equal, concat_arrays, error_handler, ArraySet, APPLICATION;
    random_bytes = detoxUtils['random_bytes'];
    string2array = detoxUtils['string2array'];
    array2string = detoxUtils['array2string'];
    are_arrays_equal = detoxUtils['are_arrays_equal'];
    concat_arrays = detoxUtils['concat_arrays'];
    error_handler = detoxUtils['error_handler'];
    ArraySet = detoxUtils['ArraySet'];
    APPLICATION = string2array('detox-chat-v0');
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
    function Chat(core_instance, real_key_seed, number_of_introduction_nodes, number_of_intermediate_nodes){
      var this$ = this;
      real_key_seed == null && (real_key_seed = null);
      number_of_introduction_nodes == null && (number_of_introduction_nodes = 3);
      number_of_intermediate_nodes == null && (number_of_intermediate_nodes = 3);
      if (!(this instanceof Chat)) {
        return new Chat(core_instance, real_key_seed, number_of_introduction_nodes, number_of_intermediate_nodes);
      }
      asyncEventer.call(this);
      this._core_instance = core_instance;
      this._real_key_seed = real_key_seed || random_bytes(ID_LENGTH);
      this._real_keypair = detoxCrypto['create_keypair'](this._real_key_seed);
      this._real_public_key = this._real_keypair['ed25519']['public'];
      this._number_of_introduction_nodes = number_of_introduction_nodes;
      this._number_of_intermediate_nodes = number_of_intermediate_nodes;
      this._max_data_size = this._core_instance['get_max_data_size']();
      this._connected_nodes = ArraySet();
      this._last_sent_date = 0;
      this._core_instance['once']('announced', function(real_public_key){
        if (this$._destroyed || !this$._is_current_chat(real_public_key)) {
          return;
        }
        this$['fire']('announced');
      })['on']('connected', function(real_public_key, friend_id){
        if (this$._destroyed || !this$._is_current_chat(real_public_key)) {
          return;
        }
        this$._connected_nodes.add(friend_id);
        this$['fire']('connected', friend_id);
      })['on']('connection_progress', function(real_public_key, friend_id, stage){
        if (this$._destroyed || !this$._is_current_chat(real_public_key)) {
          return;
        }
        this$['fire']('connection_progress', friend_id, stage);
      })['on']('connection_failed', function(real_public_key, friend_id, reason){
        if (this$._destroyed || !this$._is_current_chat(real_public_key)) {
          return;
        }
        this$['fire']('connection_failed', friend_id, reason);
      })['on']('disconnected', function(real_public_key, friend_id){
        if (this$._destroyed || !this$._is_current_chat(real_public_key)) {
          return;
        }
        this$._connected_nodes['delete'](friend_id);
        this$['fire']('disconnected', friend_id);
      })['on']('introduction', function(data){
        if (!(!this$._destroyed && this$._is_current_chat(data['real_public_key']) && are_arrays_equal(APPLICATION, data['application'].subarray(0, APPLICATION.length)))) {
          return;
        }
        return this$['fire']('introduction', data['target_id'], data['secret'], data['application']).then(function(){
          data['number_of_intermediate_nodes'] = Math.max(this$._number_of_intermediate_nodes - 1, 1);
        })['catch'](function(error){
          error_handler(error);
        });
      })['on']('data', function(real_public_key, friend_id, received_command, received_data){
        var date_array, date, text_array;
        if (this$._destroyed || !this$._is_current_chat(real_public_key)) {
          return;
        }
        switch (received_command) {
        case COMMAND_DIRECT_CONNECTION_SDP:
          break;
        case COMMAND_NICKNAME:
          this$['fire']('nickname', friend_id, array2string(received_data), received_data);
          break;
        case COMMAND_SECRET:
          if (received_data.length !== ID_LENGTH) {
            return;
          }
          this$['fire']('secret', friend_id, received_data);
          break;
        case COMMAND_TEXT_MESSAGE:
          if (received_data.length < 9) {
            return;
          }
          date_array = received_data.subarray(0, 8);
          date = date_to_number(date_array);
          text_array = received_data.subarray(8);
          this$._send(friend_id, COMMAND_RECEIVED, date_array);
          this$['fire']('text_message', friend_id, date, array2string(text_array), text_array);
          break;
        case COMMAND_RECEIVED:
          this$['fire']('received', friend_id, date_to_number(received_data));
          break;
        default:
          if (received_command < CUSTOM_COMMANDS_OFFSET) {
            return;
          }
          this$['fire']('custom_command', friend_id, received_command - CUSTOM_COMMANDS_OFFSET, received_data);
        }
      });
    }
    Chat['CONNECTION_ERROR_CANT_FIND_INTRODUCTION_NODES'] = detoxCore['CONNECTION_ERROR_CANT_FIND_INTRODUCTION_NODES'];
    Chat['CONNECTION_ERROR_NOT_ENOUGH_INTERMEDIATE_NODES'] = detoxCore['CONNECTION_ERROR_NOT_ENOUGH_INTERMEDIATE_NODES'];
    Chat['CONNECTION_ERROR_NO_INTRODUCTION_NODES'] = detoxCore['CONNECTION_ERROR_NO_INTRODUCTION_NODES'];
    Chat['CONNECTION_ERROR_CANT_CONNECT_TO_RENDEZVOUS_POINT'] = detoxCore['CONNECTION_ERROR_CANT_CONNECT_TO_RENDEZVOUS_POINT'];
    Chat['CONNECTION_ERROR_OUT_OF_INTRODUCTION_NODES'] = detoxCore['CONNECTION_ERROR_OUT_OF_INTRODUCTION_NODES'];
    Chat['CONNECTION_PROGRESS_CONNECTED_TO_RENDEZVOUS_NODE'] = detoxCore['CONNECTION_PROGRESS_CONNECTED_TO_RENDEZVOUS_NODE'];
    Chat['CONNECTION_PROGRESS_FOUND_INTRODUCTION_NODES'] = detoxCore['CONNECTION_PROGRESS_FOUND_INTRODUCTION_NODES'];
    Chat['CONNECTION_PROGRESS_INTRODUCTION_SENT'] = detoxCore['CONNECTION_PROGRESS_INTRODUCTION_SENT'];
    Chat.prototype = {
      /**
       * Announce itself to the network (can operate without announcement)
       */
      'announce': function(){
        if (this._announced || this._destroyed) {
          return;
        }
        this._announced = true;
        this._core_instance['announce'](this._real_key_seed, this._number_of_introduction_nodes, Math.max(this._number_of_intermediate_nodes - 1, 1));
      }
      /**
       * Establish connection with a friend
       *
       * @param {!Uint8Array} friend_id	Ed25519 public key of a friend
       * @param {!uint8Array} secret		Secret used for connection to a friend
       */,
      'connect_to': function(friend_id, secret){
        if (this._destroyed || this._connected_nodes.has(friend_id)) {
          return;
        }
        this._core_instance['connect_to'](this._real_key_seed, friend_id, APPLICATION, secret, this._number_of_intermediate_nodes);
      }
      /**
       * Send a nickname to a friend
       *
       * @param {!Uint8Array}			friend_id	Ed25519 public key of a friend
       * @param {string|!Uint8Array}	nickname	Nickname as string or Uint8Array to be sent to a friend
       */,
      'nickname': function(friend_id, nickname){
        if (this._destroyed || !this._connected_nodes.has(friend_id)) {
          return;
        }
        if (typeof nickname === 'string') {
          nickname = string2array(nickname);
        }
        this._send(friend_id, COMMAND_NICKNAME, nickname);
      }
      /**
       * Send a secret to a friend that will be used for future connections
       *
       * @param {!Uint8Array} friend_id	Ed25519 public key of a friend
       * @param {!Uint8Array} secret		Personal secret to be used by a friend for future connection
       */,
      'secret': function(friend_id, secret){
        var x$, secret_to_send;
        if (this._destroyed || !this._connected_nodes.has(friend_id)) {
          return;
        }
        x$ = secret_to_send = new Uint8Array(ID_LENGTH);
        x$.set(secret);
        this._send(friend_id, COMMAND_SECRET, secret_to_send);
      }
      /**
       * Send a text message to a friend
       *
       * @param {!Uint8Array}			friend_id	Ed25519 public key of a friend
       * @param {string|!Uint8Array}	text		Text message to be sent to a friend (max 65527 bytes)
       *
       * @return {number} Unix timestamp in milliseconds of the message (0 if message is empty or too big or connection is not present)
       */,
      'text_message': function(friend_id, text){
        var current_date, data;
        if (this._destroyed || !this._connected_nodes.has(friend_id)) {
          return 0;
        }
        if (typeof text === 'string') {
          text = string2array(text);
        }
        if (!text.length) {
          return 0;
        }
        current_date = +new Date;
        if (current_date <= this._last_sent_date) {
          current_date = this._last_sent_date + 1;
        }
        data = concat_arrays([date_to_array(current_date), text]);
        if (data.length > this._max_data_size) {
          return 0;
        }
        this._last_sent_date = current_date;
        this._send(friend_id, COMMAND_TEXT_MESSAGE, data);
        return current_date;
      }
      /**
       * Send custom command
       *
       * @param {!Uint8Array}	friend_id	Ed25519 public key of a friend
       * @param {number}		command		Custom command beyond Detox chat spec to be interpreted by application, 0..223
       * @param {!Uint8Array}	data		Data been sent alongside command
       */,
      'custom_command': function(friend_id, command, data){
        this._send(friend_id, command + CUSTOM_COMMANDS_OFFSET, data);
      }
      /**
       * Destroys chat instance
       */,
      'destroy': function(){
        if (this._destroyed) {
          return;
        }
        this._destroyed = true;
      }
      /**
       * @param {!Uint8Array} real_public_key
       *
       * @return {boolean}
       */,
      _is_current_chat: function(real_public_key){
        return are_arrays_equal(this._real_public_key, real_public_key);
      }
      /**
       * @param {!Uint8Array}	friend_id
       * @param {number}		command
       * @param {!Uint8Array}	data
       */,
      _send: function(friend_id, command, data){
        this._core_instance['send_to'](this._real_public_key, friend_id, command, data);
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
      /**
       * Generates random seed that can be used as keypair seed
       *
       * @return {!Uint8Array} 32 bytes
       */,
      'generate_seed': function(){
        return random_bytes(ID_LENGTH);
      }
      /**
       * Generates random secret that can be used for friends connections
       *
       * @return {!Uint8Array} 32 bytes
       */,
      'generate_secret': function(){
        return random_bytes(ID_LENGTH);
      }
    };
  }
  if (typeof define === 'function' && define['amd']) {
    define(['@detox/core', '@detox/crypto', '@detox/utils', 'fixed-size-multiplexer', 'async-eventer'], Wrapper);
  } else if (typeof exports === 'object') {
    module.exports = Wrapper(require('@detox/core'), require('@detox/crypto'), require('@detox/utils'), require('fixed-size-multiplexer'), require('async-eventer'));
  } else {
    this['detox_chat'] = Wrapper(this['detox_core'], this['detox_crypto'], this['detox_utils'], this['fixed_size_multiplexer'], this['async_eventer']);
  }
}).call(this);
