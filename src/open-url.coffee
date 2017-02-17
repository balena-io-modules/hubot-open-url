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

Personality = require('./personality.coffee')

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
		try
			get(getBookmarkFromContext(context))
			.then(-> context.send(personality.buildMessage('confirm', 'pleasantry')))
			.catch(createErrorReporter(context))
		catch error
			createErrorReporter(context)(error)

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
