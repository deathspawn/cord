require! "./util"

message-limit = 200
limit = (str, repl = " ...") ->
  if str.length > message-limit
    then "#{str.substr 0, message-limit - repl.length}#repl"
    else str

splice = (str, index, count, insert) ->
  "#{str.slice 0, index}#insert#{str.slice index + count}"

# Insert zero-width space character into nick to
# hopefully prevent them from being pinged in IRC.
ping-protect = (nick) ->
  splice nick, 1, 0, "\u200B"


module.exports = (discord, irc) !->
  return if not irc?

  irc.on \message, (message) !->
    if !message.channel? or message.notice or message.own then return
    text = limit message.text, message-limit
    text = util.irc-to-discord text, discord
    util.discord-send-channel discord, message.channel,
      if message.action then "\\* **#{message.user}** *#{text - /\s*$/}*"
      else "<**#{message.user}**> #text"
  
  discord.on \message, (message) !->
    # You receive message events from your own sent messages, so ignore those.
    if message.author.id == discord.user.id then return
    # Only relay messages to channels that the bot is actually in.
    if "##{message.channel.name}" !of irc.channels then return
    
    channel = "##{message.channel.name}"
    from = ping-protect message.author.username
    text = limit util.discord-to-irc discord, message
    
    # Format message differently if it seems to be a message generated by /me:
    # Needs to start and end with a *, no *'s in the message itself, so
    # "*this* is *bullshit*" or "*this *is* bullshit* don't count.
    if is-action = /^\*[^\*]+\*$/g.test text
      text .= substr 1, text.length - 2
    
    irc.send channel, if is-action
      then "* \x02#from\x0F #text"
      else "<\x02#from\x0F> #text"
