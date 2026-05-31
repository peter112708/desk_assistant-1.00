# spider.py
import sys
import threading
import argparse
import gc
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import requests

# 1. 精准接收传参
parser = argparse.ArgumentParser()
parser.add_argument('--port', type=int, default=18080)
parser.add_argument('--ppid', type=int, default=0)
args = parser.parse_known_args()[0]

app = FastAPI()

# 开启跨域（规范化加固）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 🛡️ Windows 专属：标准输入流阻塞守护线程（绝不残留）
def windows_suicide_watch():
    try:
        # sys.stdin.read() 是个阻塞操作
        # 只要主程序（Flutter）还在，管道就通着；一旦主程序关闭，管道破裂，这里会立刻返回空
        sys.stdin.read()
    except Exception:
        pass
    finally:
        # 发现异常或管道断开，立刻物理自杀
        import os
        os._exit(0)

# 开启守护
threading.Thread(target=windows_suicide_watch, daemon=True).start()

"""@app.get("/search")
def search_music(keyword: str):
    try:
        # 1. 🔍 使用安全的 URL 参数分离（解决 URL 编码和中文乱码问题）
        url = "https://api.oioweb.cn/api/txt/music"
        payload = {'name': keyword}
        
        response = requests.get(
            url, 
            params=payload, # 🔬 豆包提的对，用 params 自动处理中文编码
            timeout=5, 
            headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
        )
        
        if response.status_code == 200:
            res_json = response.json()
            raw_songs = res_json.get('result', [])
            
            results = []
            for item in raw_songs[:15]:
                # 2. 🔗 过滤掉那些没有播放直链的空数据（回应第 4 条链接校验）
                play_url = item.get('url', '')
                if not play_url or not play_url.startswith('http'):
                    continue
                    
                results.append({
                    'title': item.get('title', '未知歌名'),
                    'artist': item.get('author', '未知歌手'),
                    'url': play_url,
                })
            return {"code": 200, "data": results}
        return {"code": 500, "data": [], "msg": f"接口异常: {response.status_code}"}
            
    except Exception as e:
        return {"code": 500, "data": [], "msg": str(e)}
    finally:
        gc.collect() # 🧹 依然保留，因为这是把 Python 压在 20MB 内存的定海神针"""
"""@app.get("/search")
def search_music(keyword: str):
    # 🧪 绝对通电保障：直接在本地组装 3 首绝对合法的、秒级播放的高速 MP3 直链
    print(f"收到 Flutter 搜索请求，关键词: {keyword}")
    
    results = [
        {
            'title': f'{keyword} - 极速音源 A',
            'artist': 'SoundHelix 乐队',
            'url': 'http://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3' # 🔬 换成 http
        },
        {
            'title': f'{keyword} - 极速音源 B',
            'artist': 'SoundHelix 乐队',
            'url': 'http://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3' # 🔬 换成 http
        },
        {
            'title': f'{keyword} - 极速音源 C',
            'artist': 'SoundHelix 乐队',
            'url': 'http://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3' # 🔬 换成 http
        }
    ]
    return {"code": 200, "data": results}"""
@app.get("/search")
def search_music(keyword: str):
    try:
        # 🚀 终极杀招：直接请求网易云官方的网页搜索接口（国内直连，雷打不动）
        url = "https://music.163.com/api/search/get/web"
        payload = {
            's': keyword,
            'type': 1,      # 1 代表单曲检索
            'offset': 0,
            'total': 'true',
            'limit': 15     # 只取前 15 首
        }

        no_proxies = {"http": None, "https": None}
        
        # 伪装成正常的普通浏览器，防止被反爬
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'https://music.163.com/'
        }
        
        response = requests.get(
            url, 
            params=payload, 
            timeout=5, 
            proxies=no_proxies,
            headers=headers
        )
        
        if response.status_code == 200:
            res_json = response.json()
            
            # 🔬 官方接口返回的数据嵌套结构：{"result": {"songs": [...]}}
            result_data = res_json.get('result', {})
            raw_songs = result_data.get('songs', [])
            
            if not raw_songs:
                return {"code": 200, "data": [], "msg": "未搜索到相关歌曲"}
                
            results = []
            for item in raw_songs:
                song_id = item.get('id')
                if not song_id:
                    continue
                
                # 🎵 100% 可用的网易云高保真直链模板
                play_url = f"http://music.163.com/song/media/outer/url?id={song_id}.mp3"
                # 在 spider.py 循环解析歌曲列表的地方，把原本的 url 替换为这个：
                # 这是一个全网通用的高带宽音乐直链加速接口，专门用来破网易云外链限速的
                #play_url = f"https://music.xfyun.sw99.top/api/url?id={song_id}&quality=standard"
                # 或者使用这个（专门面向桌面端高并发的免限速节点）：
                #play_url = f"https://api.v0.plus/music/url?id={song_id}&source=netease"
                # 🔬 在 spider.py 里换成这个专门破 VIP 限制的通电 CDN 源
                # 它会自动去全网匹配免费的、能放的声音源，直接返回标准 MP3
                #play_url = f"https://api.v0.plus/music/url?id={song_id}&source=netease"
                # 提取歌手名字
                artists = item.get('artists', [])
                artist_name = " & ".join([a.get('name', '未知') for a in artists]) if artists else "未知歌手"
                
                results.append({
                    'title': item.get('name', '未知歌名'),
                    'artist': artist_name,
                    'url': play_url,
                })
                
            return {"code": 200, "data": results}
        
        return {"code": 500, "data": [], "msg": f"官方接口响应异常: {response.status_code}"}
        
    except Exception as e:
        print(f"🚨 请求失败: {e}")
        return {"code": 500, "data": [], "msg": str(e)}

if __name__ == "__main__":
    # 3. 🚀 规范化内置启动
    uvicorn.run(app, host="127.0.0.1", port=args.port, log_level="critical")
