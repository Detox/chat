# Detox chat [![Travis CI](https://img.shields.io/travis/Detox/chat/master.svg?label=Travis%20CI)](https://travis-ci.org/Detox/chat)
Chat library of Detox project that provides high-level APIs used when building chat application on top of Detox network.

This repository contains high level design overview (design.md, not written yet), specification for implementors (spec.md, not written yet) and reference implementation.

Library builds on top of `@detox/core` and provides simple to use API for interacting with other chat applications on Detox network.

WARNING: INSECURE UNTIL PROVEN THE OPPOSITE!!!

This protocol and reference implementation are intended to be secure, but until proper independent audit is conducted you shouldn't consider it to actually be secure and shouldn't use in production applications.

## How to install
```
npm install @detox/chat
```

## How to use
Node.js:
```javascript
var detox_chat = require('@detox/chat')

detox_chat.ready(function () {
    // Do stuff
});
```
Browser:
```javascript
requirejs(['@detox/chat'], function (detox_chat) {
    detox_chat.ready(function () {
        // Do stuff
    });
})
```

## API
### detox_chat.ready(callback)
* `callback` - Callback function that is called when library is ready for use

### detox_chat.generate_seed() : Uint8Array
Generates random seed that can be used as keypair seed in `detox_chat.Chat` constructor.

### detox_chat.generate_secret() : Uint8Array
Generates random secret that can be used for friends connections.

### detox_chat.Chat(core_instance : Object, real_key_seed = null : Uint8Array, number_of_introduction_nodes = 1 : number, number_of_intermediate_nodes = 3 : number) : detox_chat.Chat
Constructor for Chat object, uses Detox core instance for connection to the network.

* `core_instance` - Detox core instance
* `real_key_seed` - Seed used to generate real long-term keypair (if not specified - random one is used)
* `number_of_introduction_nodes` - Number of introduction nodes used for announcement to the network
* `number_of_intermediate_nodes` - How many hops should be made when making connections

### detox_chat.Chat.announce()
Announce itself to the network (can operate without announcement).

### detox_chat.Chat.connect_to(friend_id : Uint8Array, secret : Uint8Array)
Establish connection with a friend.

* `friend_id` - Ed25519 public key of a friend
* `secret` - Secret used for connection to a friend

### detox_chat.Chat.nickname(friend_id : Uint8Array, nickname : string|Uint8Array)
Send a nickname to a friend.

* `friend_id` - Ed25519 public key of a friend
* `nickname` - Nickname to be sent

### detox_chat.Chat.secret(friend_id : Uint8Array, secret : Uint8Array)
Send a secret to a friend that will be used for future connections

* `friend_id` - Ed25519 public key of a friend
* `secret` - Personal secret to be used by a friend for future connection

### detox_chat.Chat.text_message(friend_id : Uint8Array, date_written : number, text_message : string|Uint8Array) : number
Send a text message to a friend.

* `friend_id` - Ed25519 public key of a friend
* `date_written` - Unix timestamp in milliseconds when message was written
* `text_message` - Text message to be sent to a friend (max 65519 bytes)

Returns unix timestamp in milliseconds when the message was sent (0 if message is empty or too big or connection is not present).

### detox_chat.Chat.custom_command(friend_id : Uint8Array, command : number, data : Uint8Array)
Send a secret to a friend that will be used for future connections

* `friend_id` - Ed25519 public key of a friend
* `command` - Custom command beyond Detox chat spec to be interpreted by application, 0..223
* `data` - Data been sent alongside command (max 65535 bytes)

### detox_chat.Chat.destroy()
Destroys chat instance.

### detox_chat.Chat.on(event: string, callback: Function) : detox_chat.Chat
Register event handler.

### detox_chat.Chat.once(event: string, callback: Function) : detox_chat.Chat
Register one-time event handler (just `on()` + `off()` under the hood).

### detox_chat.Chat.off(event: string[, callback: Function]) : detox_chat.Chat
Unregister event handler.

### Event: introduction
Payload consists of three arguments: `friend_id` (`Uint8Array`), `secret` (`Uint8Array`) and `application` (`Uint8Array`).
Event is fired when a `friend_id` is asking for introduction for using application `application` (exactly 64 bytes) with `secret` (exactly 32 bytes as used in `connect_to` method, if supplied secret was smaller that 32 bytes then zeroes are appended).
If node decides to accept introduction and establish connection, it returns resolved Promise or returns nothing, in order to reject introduction `false` or rejected Promise should be returned.

### Event: announced
No payload.
Event is fired when announcement succeeded.

### Event: connection_failed
Payload consists of two arguments: `friend_id` (`Uint8Array`) and `reason` (`number`), which is one of `detox_chat.Chat.CONNECTION_ERROR_*` constants.
Event is fired when connection to `friend_id` failed.

### Event: connection_progress
Payload consists of two arguments: `friend_id` (`Uint8Array`) and `stage` (`number`), which is one of `detox_chat.Chat.CONNECTION_PROGRESS_*` constants.
Event is fired when there is a progress in the process of connecting to `friend_id`.

### Event: connected
Payload consists of one argument `frind_id` (`Uint8Array`).
Event is fired when connection to `frind_id` succeeded.

NOTE: Secrets are required to be updated by both sides before any further communication takes place.

### Event: disconnected
Payload consists of one argument `frind_id` (`Uint8Array`).
Event is fired when `frind_id` disconnected for whatever reason.

### Event: nickname
Payload consists of three arguments: `friend_id` (`Uint8Array`), `nickname_text` (`string`) and `nickname_array` (`Uint8Array`).
Event is fired when `frind_id` sends a nickname.

### Event: secret
Payload consists of two arguments: `friend_id` (`Uint8Array`) and `secret` (`Uint8Array`).
Event is fired when `frind_id` sends a secret.

If event is rejected (by returning `false` or rejected `Promise` from callback), then `secret_received` is not sent back to `friend_id`, which means that updated secret was not accepted (if it was used before already or for some other reason).

### Event: secret_received
Payload consists of one argument `frind_id` (`Uint8Array`).
Event is fired when `frind_id` received a secret.

### Event: text_message
Payload consists of five arguments: `friend_id` (`Uint8Array`), `date_sent` (`number`), `date_written` (`number`), `text_message_text` (`string`) and `text_message_array` (`Uint8Array`).
`date_sent` always increases (and never repeats), otherwise message should be rejected by application.
`date_written` never decreases (may repeat a few times), otherwise message should be rejected by application.
Event is fired when `frind_id` sends a text message.

### Event: text_message_received
Payload consists of two arguments: `friend_id` (`Uint8Array`) and `date` (`number`).
Event is fired when `frind_id` received a text message.

### Event: custom_command
Payload consists of three arguments: `friend_id` (`Uint8Array`), `command` (`number`) and `data` (`Uint8Array`).
Event is fired when `frind_id` sends a custom command.

## Contribution
Feel free to create issues and send pull requests (for big changes create an issue first and link it from the PR), they are highly appreciated!

When reading LiveScript code make sure to configure 1 tab to be 4 spaces (GitHub uses 8 by default), otherwise code might be hard to read.

## License
Implementation: Free Public License 1.0.0 / Zero Clause BSD License

https://opensource.org/licenses/FPL-1.0.0

https://tldrlegal.com/license/bsd-0-clause-license

Specification and design: public domain
