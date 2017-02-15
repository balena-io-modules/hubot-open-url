# Description:
#   Open a url
#
# Commands:
#   hubot open - Open the bookmark named after the room
#   hubot open named - Open the bookmark named
#   hubot <url> - Bookmark for this room
#   hubot <url> name - Bookmark for particular name
#
# Author:
#   josephroberts, okakosolikos, sqweelygig

firebaseUrl = process.env.HUBOT_FIREBASE_URL
firebaseAuth = process.env.HUBOT_FIREBASE_SECRET

bookmarks = {}
confirmations = [
	'Door unlocked.'
	"You're on the list."
	'Come on in.'
	'psssh...tsch'
	"What can I say, except 'you're welcome'!"
]
salutations = [
	'Hey there!'
	'Howdy!'
	"G'day mate!"
	'Hiya!'
	'Hi!'
	'Hello!'
]
greetings = [
	'Nice to see you!'
	'What’s up man?'
	'Sup bro?'
	'Loving those shoes!'
	'Grab a coffee.'
]

module.exports = (robot) ->
	robot.http("#{firebaseUrl}/data/bookmarks.json?auth=#{firebaseAuth}")
		.get() (err, res, body) ->
			if err? or res.statusCode isnt 200
				msg.send 'Oops?'
			else
				bookmarks = JSON.parse body

	###*
	* This creates a function to shim the http response
	* @param {function} post successes to
	* @param {function} post failures to
	* @return {function} Takes (err, res, body) and passes them to (resolve, reject)
	###
	createResolver = (resolve, reject) ->
		(err, res, body) ->
			if (not err?) and (res.statusCode is 200)
				resolve(body)
			else
				reject(err ? new Error("StatusCode: #{res.statusCode}"))

	###*
	* Attempt to visit the url referenced by key
	* @param {string} key from the bookmarks object
  * @return {Promise} Handle output from the asynchronous
	###
	open = (key) ->
		new Promise (resolve, reject) ->
			robot.http(bookmarks[key]).get() createResolver(resolve, reject)

	###*
	* Store a url in the cache and firebase
	* @param {string} key under which to store it
	* @param {string} bookmark to store
	* @return {Promise} Handle output from the asynchronous section
	###
	bookmark = (key, value) ->
		new Promise (resolve, reject) ->
			bookmarks[key] = value
			robot.http("#{firebaseUrl}/data/.json?auth=#{firebaseAuth}")
				.patch(JSON.stringify({ bookmarks: bookmarks })) createResolver(resolve, reject)

	###*
	* Extract a value from the context provided
	* @param {Object} Hubot msg object
	* @return {string} Value from the stored bookmarks
	###
	getValueFromContext = (context) ->
		if bookmarks[context.match[1]]?
			return bookmarks[context.match[1]]
		else if bookmarks[context.envelope.room]?
			return bookmarks[context.envelope.room]
		else
			throw new Error("Couldn't find key.")

	###*
	* Attempt to open the specified bookmark, defaulting to a bookmark for the room
	* (?:\W(\w+))? match up to the first word after open, capturing just the word
	###
	robot.respond /open(?:\W(\w+))?/i, (context) ->
		try
			open(getValueFromContext(context))
			.then(->
				response = [
					context.random(salutations)
					context.random(greetings)
					context.random(confirmations)
				]
				context.send(response.join(' '))
			)
			.catch (error) ->
				robot.logger.error(error)
				context.send('Something went wrong')
		catch error
			robot.logger.error(error)
			context.send('Something went wrong.')

	###*
	* Bookmark a url for the given word
	* bookmark, followed by whitespace, followed by non-whitespace (url) ...
	* followed by whitespace, followed by word (key), followed by end of string
	###
	robot.respond /bookmark\s(\S+)\s(\w+)$/i, (context) ->
		bookmark(context.match[2], context.match[1])
		.then(-> context.send('Done.'))
		.catch((error) -> context.send(error.message))

	###*
	* Bookmark a url for this room
	* bookmark, followed by whitespace, followed by non-whitespace (url), followed by end of string
	###
	robot.respond /bookmark\s(\S+)$/i, (context) ->
		bookmark(context.envelope.room, context.match[1])
		.then(-> context.send('Done.'))
		.catch((error) -> context.send(error.message))
