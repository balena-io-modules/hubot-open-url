# Description:
#   Open a url
#
# Commands:
#   hubot open - Open the bookmark named after the room
#   hubot open named - Open the bookmark named
#   hubot bookmark <url> - Bookmark for this room
#   hubot bookmark <url> name - Bookmark for particular name
#
# Author:
#   josephroberts, okakosolikos, sqweelygig

firebaseUrl = process.env.HUBOT_FIREBASE_URL
firebaseAuth = process.env.HUBOT_FIREBASE_SECRET

bookmarks = {}

# These classes are a prime candidate to become their own module, but not now
class PersonalityError extends Error
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
			marvin:
				greeting: ["Lousy day isn't it?"]
				confirm: ['Another menial task complete.']
				holding: ["A brain the size of a planet, and this is what I'm doing"]
				pleasantry: [ # irony
					'Did I tell you about the pain in all the diodes down my left side.'
					"I don't expect you to care about me."
					"It's a lonely life."
				]
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
		@fallbacks =
			configured: 'confirm'
			greeting: 'pleasantry'
		@phrases =
			confirm: ['Done.']
			holding: ['Doing.']
		for purpose, bank of personalities[personality] ? {}
			@phrases[purpose] = bank

	###*
	* Creates a message from the personality bank
	* @param {string} purpose - the reason for this text
	* @param {string} extra - context for the time in the conversation
	* (greeting, pleasantry, departure)
	* @return {string} - a suitable text for output to the user
	###
	buildMessage: (purpose, extra) ->
		text = [@getText(purpose)]
		if extra?
			try
				text.unshift(@getText(extra))
			catch error
				if not(error instanceof PersonalityError) then throw error
		return text.join(' ')

	###*
	* Gets a string from the personality bank
	* @param {string} purpose - the meaning to convey
	* @return {string} - The phrase from the bank
	###
	getText: (purpose) ->
		if @phrases[purpose]?
			return @random(@phrases[purpose])
		else if @phrases[@fallbacks[purpose]]?
			return @random(@phrases[@fallbacks[purpose]])
		else
			throw new PersonalityError("Text not found for #{purpose}")

	###*
	* Returns a random element from an array
	* @param {Array <T>} items - array to select from
	* @return {<T>} - random item from the array
	###
	random: (items) ->
		items[Math.floor(Math.random() * items.length)]

module.exports = (robot) ->
	personality = new Personality(process.env.HUBOT_PERSONALITY)
	robot.http("#{firebaseUrl}/data/bookmarks.json?auth=#{firebaseAuth}")
		.get() (err, res, body) ->
			if err? or res.statusCode isnt 200
				msg.send 'Oops?'
			else
				bookmarks = JSON.parse body

	###*
	* Creates a function that converts a Hubot HTTP response into a Promise resolution
	* @param {function} resolve - a function for successful http requests
	* @param {function} reject - a function for http errors
	* @return {function} - a function that converts Hubot http responses
	* (err, res, body) and renders them to a Promise function (resolve, reject)
	###
	createResolver = (resolve, reject) ->
		(err, res, body) ->
			if (not err?) and (res.statusCode is 200)
				resolve(body)
			else
				reject(err ? new Error("StatusCode: #{res.statusCode}; Body: #{body}"))

	###*
	* Creates a function that communicates an error.
	* @param {Object} context - A Hubot msg object
	* @return {function} - a function that takes (error) and communicates it
	###
	createErrorReporter = (context) ->
		(error) ->
			robot.logger.error(error)
			context.send('Something went wrong. Debug output logged')

	###*
	* Attempt to get the url referenced in a Promise resolution rather than (err, res, body)
	* @param {string} url - address of the web site to get
	* @return {Promise} - A promise for the response for the given url
	###
	get = (url) ->
		new Promise (resolve, reject) ->
			robot.http(url).get() createResolver(resolve, reject)

	###*
	* Store a url in the cache and firebase
	* @param {string} namespace - a namespace under which to store the value
	* @param {string} key - a name for the value
	* @param {string} value - url to store
	* @return {Promise} - A promise for the response from storing the given pair
	###
	bookmark = (namespace, key, value) ->
		new Promise (resolve, reject) ->
			bookmarks[namespace] ?= {}
			bookmarks[namespace][key] = value
			robot.http("#{firebaseUrl}/data/.json?auth=#{firebaseAuth}")
				.patch(JSON.stringify({ bookmarks: bookmarks })) createResolver(resolve, reject)

	###*
	* Extract a value from the context provided.
	* Attempts to use first match then room name.
	* @param {Object} context - A Hubot msg object
	* @return {string} - Value from the stored bookmarks
	###
	getBookmarkFromContext = ({ match: [_, bookmarkName], envelope: { room: roomName } }) ->
		if bookmarkName?
			scope = 'named'
			key = bookmarkName
		else if roomName?
			scope = 'rooms'
			key = roomName
		else
			throw new Error('No key specified.')
		if bookmarks[scope]?[key]?
			return bookmarks[scope][key]
		else
			throw new Error('Unknown key.')

	###*
	* Attempt to open the specified bookmark, defaulting to a bookmark for the room
	###
	# (?:\W(\w+))? match up to the first word after open, capturing just the word
	robot.respond /open(?:\W(\w+))?/i, (context) ->
		context.send(personality.buildMessage('holding', 'greeting'))
		Promise.try ->
			get(getBookmarkFromContext(context))
		.then(-> context.send(personality.buildMessage('confirm', 'pleasantry')))
		.catch(createErrorReporter(context))

	###*
	* Bookmark a url for the given word
	###
	# bookmark, followed by whitespace, followed by non-whitespace (url) ...
	# followed by whitespace, followed by word (key), followed by end of string
	robot.respond /bookmark\s(\S+)\s(\w+)$/i, (context) ->
		bookmark('named', context.match[2], context.match[1])
		.then(-> context.send(personality.buildMessage('configured')))
		.catch(createErrorReporter(context))

	###*
	* Bookmark a url for this room
	###
	# bookmark, followed by whitespace, followed by non-whitespace (url), followed by end of string
	robot.respond /bookmark\s(\S+)$/i, (context) ->
		bookmark('rooms', context.envelope.room, context.match[1])
		.then(-> context.send(personality.buildMessage('configured')))
		.catch(createErrorReporter(context))
