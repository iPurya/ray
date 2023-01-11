from telebot import TeleBot
from redis import Redis
import config

redis = Redis(db=5 , charset="utf-8", decode_responses=True)

bot = TeleBot(config.BOT_TOKEN)
print(f"Bot Started @{bot.get_me().username}")

@bot.message_handler()
def msg_handler(msg):
    text = str(msg.text or msg.caption or '')
    chat_id = msg.chat.id
    from_id = msg.from_user.id
    if not from_id in config.ADMINS: return
    print(chat_id,text)
    if text == '/start':
        bot.reply_to(msg,"Hello World!")
    
bot.infinity_polling(skip_pending=True)
