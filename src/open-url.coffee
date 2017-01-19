# Description:
#   Open a url
#
# Commands:
#   hubot open - Open the bookmark named after the room
#   hubot open named - Open the bookmark named
#
# Author:
#   josephroberts, okakosolikos, sqweelygig

firebaseUrl = process.env.HUBOT_FIREBASE_URL
firebaseAuth = process.env.HUBOT_FIREBASE_SECRET

bookmarks = {}
confirmations = [
	'Hey man, nice to see you'
	'Howdy!'
	"G'day mate!"
	'Hiya!'
	'What’s up man'
	'Sup bro?'
	'Yeah man, on it'
	'Oh, wow, love those shoes!'
]

module.exports = (robot) ->
	robot.http("#{firebaseUrl}/data/bookmarks.json?auth=#{firebaseAuth}")
		.get() (err, res, body) ->
			if err or res.statusCode isnt 200
				msg.send 'Oops?'
			else
				bookmarks = JSON.parse body

	open = (key, callback) ->
		if bookmarks[key]?
			robot.http(bookmarks[key]).get() (err, res, body) ->
				callback (not err?) and res.statusCode is 200

	bookmark = (key, value, callback) ->
		bookmarks[key] = value
		robot.http("#{firebaseUrl}/data/.json?auth=#{firebaseAuth}")
			.patch(JSON.stringify({ bookmarks: bookmarks })) (err, res, body) ->
				callback (not err?) and res.statusCode is 200

	robot.respond /open (\S+)( office| sesame)?$/i, (context) ->
		open context.match[1], (done) ->
			context.send if done then context.random confirmations else "Couldn't find " + context.match[1] + ' key.'

	robot.respond /open( office| sesame)?$/i, (context) ->
		open context.envelope.room, (done) ->
			context.send if done then context.random confirmations else "Couldn't find " + context.envelope.room + ' key.'

	robot.respond /bookmark (\S+) (\S+)$/i, (context) ->
		bookmark context.match[2], context.match[1], (done) ->
			context.send if done then 'Done.' else 'Oops! (c)'

	robot.respond /bookmark (\S+)$/i, (context) ->
		bookmark context.envelope.room, context.match[1], (done) ->
			context.send if done then 'Done.' else 'Oops! (d)'
