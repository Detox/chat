# Detox Chat protocol design

Complements specification version: 0.1.0

Author: Nazar Mokrynskyi

License: Detox Chat design (this document) is hereby placed in the public domain

### Introduction
This document is a high level design overview of the Detox Chat protocol.
The goal of this document is to give general understanding what Detox Chat protocol is, how it works and why it is designed the way it is.

Refer to the specification if you intend to create alternative implementation.

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED",  "MAY", and "OPTIONAL" in this document are to be interpreted as described in IETF [RFC 2119](http://www.ietf.org/rfc/rfc2119.txt).

### Glossary
* Contact: node in Detox network that implements Detox Chat application protocol
* Contact request: Initial connection of new contact

### What Detox Chat is
Detox Chat is a simple application protocol on top of Detox network for messaging purposes.

It aims to provide a secure and extensible framework for building compatible chat applications.

### Foundation
Detox Chat works on top of [Detox network](https://github.com/Detox/core), make yourself familiar with Detox network first as this document will not cover it.

Detox Chat is only one possible protocol that works on top of Detox network.
Detox Chat offers only basic set of features that can be extended by implementations using custom set of commands on top of Detox Chat specification.
This means that basic set of features will work in any correct implementation, but more advanced capabilities may not be supported by every implementation.

### Core features
Protocol is designed to be as simple as possible while allowing extensibility, following features MUST be supported by all implementations:
* sending, receiving and accepting contacts requests
* sending and receiving nicknames
* sending and receiving text messages

### Security considerations
On top of security and anonymity features offered by Detox network itself, following are supported by Detox Chat protocol:
* frequent per-contact unique one-time secrets rotation
* contact's keys compromise detection
* partial post-compromise security

Application built with Detox Chat protocol will exchange one-time secrets between contacts on each connection establishment prior to any further communication.
If your machine was compromised and an someone got access to all of the application data, there are still some things Detox Chat protocol does for you to reduce potential damage.
In particular, if you have at least one conversation after initial compromise with specific contact:
* an attacker will not be able to pretend being you, since secrets will already be changed and you can continue to communicate in a secure way with such contact
* if an attacker tries to initiate connection on your behalf, your contact will know approximate time when compromise happened by the time when outdated secrets were generated and will be able to notify you about this using some other channels

This is on top of future secrecy offered by Detox network itself.

### Text messages contents
Text messages SHOULD be treated as Markdown markup ([GFM](https://github.github.com/gfm/) flavor), but:
* with images being rendered as links (because otherwise they are loaded unconditionally and may lead to de-anonymization)
* without raw HTML support, all raw HTML will be rendered as text

Since Markdown is a human-readable format, lighter clients may render it as simple text.

### Acknowledgements
Detox Chat protocol is inspired by [Tox](https://tox.chat/).
