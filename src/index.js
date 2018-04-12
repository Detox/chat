// Generated by LiveScript 1.5.0
/**
 * @package Detox chat
 * @author  Nazar Mokrynskyi <nazar@mokrynskyi.com>
 * @license 0BSD
 */
(function(){
  /*
   * Implements version 0.2.0 of the specification
   */
  var COMMAND_DIRECT_CONNECTION_SDP, COMMAND_SECRET, COMMAND_SECRET_RECEIVED, COMMAND_NICKNAME, COMMAND_TEXT_MESSAGE, COMMAND_TEXT_MESSAGE_RECEIVED, CUSTOM_COMMANDS_OFFSET, ID_LENGTH;
  COMMAND_DIRECT_CONNECTION_SDP = 0;
  COMMAND_SECRET = 1;
  COMMAND_SECRET_RECEIVED = 2;
  COMMAND_NICKNAME = 3;
  COMMAND_TEXT_MESSAGE = 4;
  COMMAND_TEXT_MESSAGE_RECEIVED = 5;
  CUSTOM_COMMANDS_OFFSET = 64;
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
  function Wrapper(detoxCore, detoxCrypto, detoxUtils, asyncEventer){
    var random_bytes, string2array, array2string, hex2array, array2hex, are_arrays_equal, concat_arrays, error_handler, ArraySet, base58_encode, base58_decode, blake2b_256, APPLICATION;
    random_bytes = detoxUtils['random_bytes'];
    string2array = detoxUtils['string2array'];
    array2string = detoxUtils['array2string'];
    hex2array = detoxUtils['hex2array'];
    array2hex = detoxUtils['array2hex'];
    are_arrays_equal = detoxUtils['are_arrays_equal'];
    concat_arrays = detoxUtils['concat_arrays'];
    error_handler = detoxUtils['error_handler'];
    ArraySet = detoxUtils['ArraySet'];
    base58_encode = detoxUtils['base58_encode'];
    base58_decode = detoxUtils['base58_decode'];
    blake2b_256 = detoxCrypto['blake2b_256'];
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
      this._connection_secret_updated_local = ArraySet();
      this._connection_secret_updated_remote = ArraySet();
      this._last_date_sent = 0;
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
        this$._connection_secret_updated_local['delete'](friend_id);
        this$._connection_secret_updated_remote['delete'](friend_id);
        this$['fire']('disconnected', friend_id);
      })['on']('introduction', function(data){
        if (!(!this$._destroyed && this$._is_current_chat(data['real_public_key']) && are_arrays_equal(APPLICATION, data['application'].subarray(0, APPLICATION.length)))) {
          return;
        }
        return this$['fire']('introduction', data['target_id'], data['secret'], data['application']).then(function(){
          data['number_of_intermediate_nodes'] = Math.max(this$._number_of_intermediate_nodes - 1, 1);
        });
      })['on']('data', function(real_public_key, friend_id, received_command, received_data){
        var date_sent_array, date_sent, date_written_array, date_written, text_array;
        if (this$._destroyed || !this$._is_current_chat(real_public_key)) {
          return;
        }
        if (!((received_command === COMMAND_SECRET || received_command === COMMAND_SECRET_RECEIVED) || this$._secrets_updated(friend_id))) {
          return;
        }
        switch (received_command) {
        case COMMAND_DIRECT_CONNECTION_SDP:
          break;
        case COMMAND_SECRET:
          if (received_data.length !== ID_LENGTH) {
            return;
          }
          this$['fire']('secret', friend_id, received_data).then(function(){
            this$._connection_secret_updated_remote.add(friend_id);
            this$._send(friend_id, COMMAND_SECRET_RECEIVED, new Uint8Array(0));
          })['catch'](error_handler);
          break;
        case COMMAND_SECRET_RECEIVED:
          if (!this$._connection_secret_updated_local.has(friend_id)) {
            return;
          }
          this$['fire']('secret_received', friend_id);
          break;
        case COMMAND_NICKNAME:
          this$['fire']('nickname', friend_id, array2string(received_data), received_data);
          break;
        case COMMAND_TEXT_MESSAGE:
          if (received_data.length < 9) {
            return;
          }
          date_sent_array = received_data.subarray(0, 8);
          date_sent = date_to_number(date_sent_array);
          date_written_array = received_data.subarray(8, 16);
          date_written = date_to_number(date_written_array);
          text_array = received_data.subarray(16);
          this$._send(friend_id, COMMAND_TEXT_MESSAGE_RECEIVED, date_sent_array);
          this$['fire']('text_message', friend_id, date_sent, date_written, array2string(text_array), text_array);
          break;
        case COMMAND_TEXT_MESSAGE_RECEIVED:
          this$['fire']('text_message_received', friend_id, date_to_number(received_data));
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
       * @param {!Uint8Array} secret		Secret used for connection to a friend
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
        this._connection_secret_updated_local.add(friend_id);
        this._send(friend_id, COMMAND_SECRET, secret_to_send);
      }
      /**
       * Send a text message to a friend
       *
       * @param {!Uint8Array}			friend_id		Ed25519 public key of a friend
       * @param {number}				date_written	Unix timestamp in milliseconds when message was written
       * @param {string|!Uint8Array}	text			Text message to be sent to a friend (max 65519 bytes)
       *
       * @return {number} Unix timestamp in milliseconds when the message was sent (0 if message is empty or too big or connection is not present)
       */,
      'text_message': function(friend_id, date_written, text){
        var date_sent, data;
        if (this._destroyed || !this._connected_nodes.has(friend_id)) {
          return 0;
        }
        if (typeof text === 'string') {
          text = string2array(text);
        }
        if (!text.length) {
          return 0;
        }
        date_sent = +new Date;
        if (date_sent <= this._last_date_sent) {
          date_sent = this._last_date_sent + 1;
        }
        data = concat_arrays([date_to_array(date_sent), date_to_array(date_written), text]);
        if (data.length > this._max_data_size) {
          return 0;
        }
        this._last_date_sent = date_sent;
        this._send(friend_id, COMMAND_TEXT_MESSAGE, data);
        return date_sent;
      }
      /**
       * Send custom command
       *
       * @param {!Uint8Array}	friend_id	Ed25519 public key of a friend
       * @param {number}		command		Custom command beyond Detox chat spec to be interpreted by application, 0..223
       * @param {!Uint8Array}	data		Data been sent alongside command (max 65535 bytes)
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
       * @param {!Uint8Array} friend_id
       *
       * @return {boolean}
       */,
      _secrets_updated: function(friend_id){
        return this._connection_secret_updated_local.has(friend_id) && this._connection_secret_updated_remote.has(friend_id);
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
    /**
     * @param {!Uint8Array} payload
     *
     * @return {string}
     */
    function base58_check_encode(payload){
      var checksum;
      checksum = blake2b_256(payload).subarray(0, 2);
      return base58_encode(concat_arrays([payload, checksum]));
    }
    /**
     * @param {string} string
     *
     * @return {!Uint8Array}
     *
     * @throws {Error}
     */
    function base58_check_decode(string){
      var decoded_array, payload, checksum;
      decoded_array = base58_decode(string);
      payload = decoded_array.subarray(0, -2);
      checksum = decoded_array.subarray(-2);
      if (!are_arrays_equal(blake2b_256(payload).subarray(0, 2), checksum)) {
        throw new Error('Checksum is not correct');
      }
      return payload;
    }
    /**
     * Encodes public key and secret into base58 string with built-in checksum
     *
     * @param {!Uint8Array} public_key
     * @param {!Uint8Array} secret
     *
     * @return {string}
     */
    function id_encode(public_key, secret){
      return base58_check_encode(concat_arrays([public_key, secret]));
    }
    /**
     * Decodes encoded public key and secret from base58 string and checks built-in checksum
     *
     * @param {string} string
     *
     * @return {!Array<!Uint8Array>} [public_key, secret]
     *
     * @throws {Error} When checksum or ID is not correct
     */
    function id_decode(string){
      var payload, public_key, secret;
      payload = base58_check_decode(string);
      if (payload.length < ID_LENGTH || payload.length > ID_LENGTH * 2) {
        throw new Error('Incorrect ID');
      }
      public_key = payload.subarray(0, ID_LENGTH);
      secret = payload.subarray(ID_LENGTH);
      return [public_key, secret];
    }
    /**
     * Encodes ID, host and port of bootstrap node into base58 string with built-in checksum
     *
     * @param {string} id
     * @param {string} host
     * @param {number} port
     *
     * @return {string}
     */
    function bootstrap_node_encode(id, host, port){
      return base58_check_encode(concat_arrays([hex2array(id), string2array(host), new Uint8Array(Uint16Array.of(port).buffer)]));
    }
    /**
     * Decodes encoded ID, host and port from base58 string and checks built-in checksum
     *
     * @param {string} string
     *
     * @return {!Array} [id, host, port]
     *
     * @throws {Error} When checksum or bootstrap node information is not correct
     */
    function bootstrap_node_decode(string){
      var payload, id, host, port;
      payload = base58_check_decode(string);
      if (payload.length < ID_LENGTH + 1 + 2) {
        throw new Error('Incorrect bootstrap node information');
      }
      id = array2hex(payload.subarray(0, ID_LENGTH));
      host = array2string(payload.subarray(ID_LENGTH, -2));
      port = new Uint16Array(payload.slice(-2).buffer)[0];
      return [id, host, port];
    }
    Object.defineProperty(Chat.prototype, 'constructor', {
      value: Chat
    });
    return {
      'ready': function(callback){
        detoxCore['ready'](function(){
          detoxCrypto['ready'](function(){
            callback();
          });
        });
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
      },
      'id_encode': id_encode,
      'id_decode': id_decode,
      'bootstrap_node_encode': bootstrap_node_encode,
      'bootstrap_node_decode': bootstrap_node_decode
    };
  }
  if (typeof define === 'function' && define['amd']) {
    define(['@detox/core', '@detox/crypto', '@detox/utils', 'async-eventer'], Wrapper);
  } else if (typeof exports === 'object') {
    module.exports = Wrapper(require('@detox/core'), require('@detox/crypto'), require('@detox/utils'), require('async-eventer'));
  } else {
    this['detox_chat'] = Wrapper(this['detox_core'], this['detox_crypto'], this['detox_utils'], this['async_eventer']);
  }
}).call(this);
