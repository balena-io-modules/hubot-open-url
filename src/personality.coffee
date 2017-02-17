# These classes are a prime candidate to become their own module, but not now
_ = require 'lodash'

class Personality
	###*
	* Creates a Personality object that handles creating flavourful messages
	* for a variety of circumstances
	* @param {string} personality - index of the personality to load
	###
	constructor: (personality) ->
		personalities =
			rude:
				confirm: ['Done it.']
				holding: ["Shut up and wait, I'll do it"]
				departure: ['You can go away now.']
				deny: ["Sod off, I'm not doing that"]
			marvin:
				greeting: ["Lousy day isn't it?"]
				confirm: ['Another menial task complete.']
				holding: ["A brain the size of a planet, and this is what I'm doing"]
				pleasantry: [ # irony
					'Did I tell you about the pain in all the diodes down my left side.'
					"I don't expect you to care about me."
					"It's a lonely life."
				]
				deny: ["I could do that easily, but I'm not allowed"]
			gpp: # Genuine People Personality
				greeting: [
					'Hey there!'
					'Howdy!'
					'Hiya!'
					'Hi!'
					'Hello!'
				]
				pleasantry: [
					'Nice to see you!'
					'What’s up man?'
					'Sup bro?'
					'Loving those shoes!'
					'Grab a coffee.'
				]
				configured: [
					'Done.'
					'Thanks!'
					'Got it.'
				]
				confirm: [
					'Door unlocked.'
					"You're on the list."
					'Come on in.'
					'psssh...tsch.'
				]
				holding: [
					'Working on it.'
					'Doing that now.'
					'Gimme a moment.'
				]
				deny: [
					'Ermm, sorry and all, but no.'
				]
		@fallbacks =
			configured: 'confirm'
			greeting: 'pleasantry'
		@phrases =
			confirm: ['Done.']
			holding: ['Doing.']
			deny: ["Can't do"]
		for purpose, bank of personalities[personality] ? {}
			@phrases[purpose] = bank

	###*
	* Creates a message from the personality bank
	* @param {string} purpose - the reason for this text, will error if unavailable
	* @param {string} extra - an optional pre-text, often used for placing
	* the comment in the conversation flow.
	* (greeting, pleasantry, departure)
	* @return {string} - a suitable text for output to the user
	###
	buildMessage: (purpose, extra) ->
		text = []

		core = @getText(purpose)
		if not core? then throw new Error("Text not found for #{purpose}")
		text.push(core)

		fluff = @getText(extra)
		if fluff? then text.unshift(@getText(extra))

		return text.join(' ')

	###*
	* Gets a string from the personality bank
	* @param {string} purpose - the meaning to convey
	* @return {string} - The phrase from the bank
	###
	getText: (purpose) ->
		if @phrases[purpose]?
			return _.sample(@phrases[purpose])
		else if @phrases[@fallbacks[purpose]]?
			return _.sample(@phrases[@fallbacks[purpose]])
		else
			return null

module.exports = Personality
