from paramiko.client import SSHClient, AutoAddPolicy
from telebot import TeleBot
from redis import Redis
import digitalocean
import config
import time
import re

redis = Redis(db=5 , charset="utf-8", decode_responses=True)

bot = TeleBot(config.BOT_TOKEN)
print(f"Bot Started @{bot.get_me().username}")

manager = digitalocean.Manager(token=config.DO_API_KEY)
keys = manager.get_all_sshkeys() # sshkey manually added from digitalocean panel

def ssh_connect(ip_address):
    client = SSHClient()
    client.load_system_host_keys()
    client.set_missing_host_key_policy(AutoAddPolicy())
    client.connect(ip_address, username="root", key_filename="id_rsa")
    stdin, stdout, stderr = client.exec_command('hostname')

@bot.message_handler()
def msg_handler(msg):
    text = str(msg.text or msg.caption or '')
    chat_id = msg.chat.id
    from_id = msg.from_user.id
    if not from_id in config.ADMINS: return
    print(chat_id,text)
    if text == '/start':
        bot.reply_to(msg,"Hello World!")
    elif text == "/do_list":
        txt = "DigitalOcean Servers List:\n\n"
        my_droplets = manager.get_all_droplets()
        for i,droplet in enumerate(my_droplets):
            txt += f"{i+1}. {droplet.name} — {droplet.ip_address} — {droplet.status} — {droplet.region.get('name')} — /do_delete_{droplet.id} \n"
        bot.send_message(chat_id,txt)
    elif match := re.match(r"/do_delete_(\d+)", text):
        try:
            droplet = manager.get_droplet(int(match.group(1)))
            droplet.destroy()
            bot.reply_to(msg, f"Droplet `{droplet.name}` destroyed!",parse_mode="markdown")
        except: bot.reply_to(msg, "Droplet not found or something is wrong!")
    elif text == "/do_create":
        droplet = digitalocean.Droplet(token=DO_API_KEY,
                               name=f'vps-{random.randint(10000,99999)}',
                               region='ams3', # pick random region later or get it from user
                               image='ubuntu-20-04-x64', # Ubuntu 20.04 x64
                               size_slug='s-1vcpu-1gb-amd',  # 1GB RAM, 1 vCPU - $7 (maybe $4 later)
                               ssh_keys=keys)
        droplet.create()
        done = False
        while not done:
            actions = droplet.get_actions()
            for action in actions:
                action.load()
                if action.status == "completed":
                    done = True
                    break
            time.sleep(1)
        droplet = manager.get_droplet(droplet.id)
        bot.reply_to(msg,f"Created {droplet.name} — {droplet.region.get('name')} — {droplet.ip_address}")
bot.infinity_polling(skip_pending=True)
