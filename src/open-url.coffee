# Description:
#   Open a url
#
# Commands:
#   hubot open - Open the bookmark named after the thread
#   hubot open named - Open the bookmark named
#
# Author:
#   josephroberts, okakosolikos, sqweelygig

firebaseUrl = process.env.HUBOT_FIREBASE_URL
firebaseAuth = process.env.HUBOT_FIREBASE_SECRET

bookmarks = {}

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

	robot.respond /open (\S*)$/i, (context) ->
		open context.match[1], (done) ->
			context.send if done then 'Done.' else 'Oops! (a)'

	robot.respond /open$/i, (context) ->
		open context.envelope.room, (done) ->
			context.send if done then 'Done.' else 'Oops! (b)'

	robot.respond /bookmark (\S*) (\S*)$/i, (context) ->
		bookmark context.match[2], context.match[1], (done) ->
			context.send if done then 'Done.' else 'Oops! (c)'

	robot.respond /bookmark (\S*)$/i, (context) ->
		bookmark context.envelope.room, context.match[1], (done) ->
			context.send if done then 'Done.' else 'Oops! (d)'
