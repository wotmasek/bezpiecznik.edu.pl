# Submit MiniMax H3 image-to-video jobs to local ComfyUI, wait, copy results.
import json, sys, time, urllib.request, shutil, glob, os
URL = "http://127.0.0.1:8188"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "wideo")
SHOTS = {
 "A_ulica": ("A_ulica_22.png", "Static locked-off camera, documentary night footage filmed from an upper-floor window of a Polish housing estate in light drizzle.\n\nTimeline:\n[0s-1s] Everything is still, orange sodium streetlights glow, many apartment windows are lit.\n[1s-3s] A power blackout rolls across the estate: the streetlights go dark one after another from far to near, then the windows of the apartment blocks go dark floor by floor, until only the faint orange sky glow and two car headlights remain.\n\nNo camera movement, no people, photorealistic, natural sensor grain.\n\nAudio: distant city hum and electrical buzz cutting out to silence, light rain."),
 "C_powodz": ("C_powodz_22.png", "Handheld news camera footage of a flooded small Polish town street in steady rain, slight natural handheld sway.\n\nTimeline:\n[0s-3s] Brown muddy floodwater flows down the street from back to front, small waves lap against the abandoned half-submerged car, debris and branches drift past, raindrops hit the water surface, the rescue boat far in the background drifts slowly.\n\nThe car is abandoned and completely switched off: its windshield wipers stay perfectly still, no lights on the car, nothing on the car moves except water flowing around it. Buildings stay rigid and unchanged.\n\nNo cuts, no people in close-up, photorealistic, natural grain.\n\nAudio: rushing water, heavy rain."),
 "C2_powodz": ("C_powodz_11.png", "Handheld news camera footage of a flooded small Polish town street in steady rain, slight natural handheld sway.\n\nTimeline:\n[0s-3s] Brown muddy floodwater flows down the street from back to front, small waves lap against the abandoned half-submerged car, debris and branches drift past, raindrops hit the water surface, the rescue boat far in the background drifts slowly.\n\nThe car is abandoned and completely switched off: its windshield wipers stay perfectly still, no lights on the car, nothing on the car moves except water flowing around it. Buildings stay rigid and unchanged.\n\nNo cuts, no people in close-up, photorealistic, natural grain.\n\nAudio: rushing water, heavy rain."),
 "B2_okno": ("B_okno_22_noc.png", "Static locked-off camera inside a dark apartment at 3 a.m., looking out through the window at Polish apartment blocks. It is deep night: there is no sun, no sunset and no sunrise, the sky stays dark grey-black.\n\nTimeline:\n[0s-1s] Stillness, the net curtain barely moves.\n[1s-1.4s] A sudden short white-orange explosion flash far behind the blocks, irregular in shape, briefly lights the underside of the clouds and the room.\n[1.4s-3s] The flash dies out within a second, leaving a small dim orange glow low on the horizon and a dark smoke column rising.\n\nNo round glowing disc, no sun. No camera movement, no people, photorealistic, natural sensor grain.\n\nAudio: deep distant explosion rumble, window glass rattling, then silence."),
 "B3_okno": ("B3_okno_44.png", "Static locked-off camera inside a pitch-dark apartment at 3 a.m., looking out through the window at Polish apartment blocks under a dark night sky with heavy low clouds.\n\nTimeline:\n[0s-1s] Stillness, the net curtain barely moves, a few windows lit.\n[1s-1.3s] Air defence intercepts a drone high in the sky: a sudden bright white-orange burst flashes INSIDE the low clouds above the blocks, lighting the clouds from within and briefly lighting the dark room and the curtain.\n[1.3s-3s] The light dies out at once, a few glowing sparks fall slowly from the clouds, the sky is dark again.\n\nIt stays deep night the whole time: no sun, no sunrise, no glow on the horizon, nothing round and glowing. No camera movement, no people, photorealistic, natural sensor grain.\n\nAudio: sharp distant explosion, window glass rattling, then silence."),
 "B3b_okno": ("B3_okno_55.png", "Static locked-off camera inside a pitch-dark apartment at 3 a.m., looking out through the window at Polish apartment blocks under a dark night sky with heavy low clouds.\n\nTimeline:\n[0s-1s] Stillness, the net curtain barely moves, a few windows lit.\n[1s-1.3s] Air defence intercepts a drone high in the sky: a sudden bright white-orange burst flashes INSIDE the low clouds above the blocks, lighting the clouds from within and briefly lighting the dark room and the curtain.\n[1.3s-3s] The light dies out at once, a few glowing sparks fall slowly from the clouds, the sky is dark again.\n\nIt stays deep night the whole time: no sun, no sunrise, no glow on the horizon, nothing round and glowing. No camera movement, no people, photorealistic, natural sensor grain.\n\nAudio: sharp distant explosion, window glass rattling, then silence."),
 "B_okno": ("B_okno_22.png", "Static locked-off camera inside a dark apartment, looking out through the window at Polish apartment blocks at night.\n\nTimeline:\n[0s-1s] Stillness, the net curtain barely moves.\n[1s-1.5s] A sudden bright orange-white flash on the far horizon lights up the underside of the clouds and briefly illuminates the room and the curtain.\n[1.5s-3s] The glow fades to a dim orange, a faint smoke column rises far away.\n\nNo camera movement, no people, photorealistic, natural sensor grain.\n\nAudio: deep distant explosion rumble, window glass rattling, then silence."),
}
def graph(img, prompt, seed):
    return {
     "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "minimax_h3_fl2va_pruned_int8_convrot.safetensors", "weight_dtype": "default"}},
     "2": {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["1", 0], "lora_name": "minimax_h3_fl2v_turbo_8step_v1.0_comfyui_bf16.safetensors", "strength_model": 1.0}},
     "3": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors", "type": "minimax", "device": "default"}},
     "4": {"class_type": "VAELoader", "inputs": {"vae_name": "minimax_h3_video_vae_fp16.safetensors"}},
     "6": {"class_type": "LoadImage", "inputs": {"image": img}},
     "7": {"class_type": "ImageScale", "inputs": {"image": ["6", 0], "upscale_method": "lanczos", "width": 1344, "height": 768, "crop": "center"}},
     "8": {"class_type": "MiniMaxH3ImageToVideo", "inputs": {"clip": ["3", 0], "vae": ["4", 0], "first_frame": ["7", 0], "prompt": prompt, "width": 1344, "height": 768, "length": 73}},
     "9": {"class_type": "RandomNoise", "inputs": {"noise_seed": seed}},
     "10": {"class_type": "KSamplerSelect", "inputs": {"sampler_name": "res_multistep"}},
     "11": {"class_type": "BasicScheduler", "inputs": {"model": ["2", 0], "scheduler": "simple", "steps": 8, "denoise": 1.0}},
     "12": {"class_type": "BasicGuider", "inputs": {"model": ["2", 0], "conditioning": ["8", 0]}},
     "13": {"class_type": "SamplerCustomAdvanced", "inputs": {"noise": ["9", 0], "guider": ["12", 0], "sampler": ["10", 0], "sigmas": ["11", 0], "latent_image": ["8", 1]}},
     "14": {"class_type": "VAEDecode", "inputs": {"samples": ["13", 0], "vae": ["4", 0]}},
     "15": {"class_type": "SaveImage", "inputs": {"images": ["14", 0], "filename_prefix": "bezpiecznik/" + img[:-4] + f"_s{seed}/f"}},
    }
def post(g):
    r = urllib.request.urlopen(urllib.request.Request(URL + "/prompt", json.dumps({"prompt": g}).encode(), {"Content-Type": "application/json"}))
    return json.load(r)["prompt_id"]
ids = []
for name in sys.argv[1:] or SHOTS:
    img, p = SHOTS[name]
    for seed in [int(x) for x in os.environ.get('SEEDS','1').split(',')]:
        try: ids.append((name, post(graph(img, p, seed))))
        except urllib.error.HTTPError as e: print("ERR", name, e.read().decode()[:1500]); sys.exit(1)
print("queued", ids, flush=True)
t0 = time.time()
while ids:
    time.sleep(10)
    for name, pid in list(ids):
        h = json.load(urllib.request.urlopen(f"{URL}/history/{pid}"))
        if pid in h:
            st = h[pid].get("status", {})
            print(name, st.get("status_str"), "%.0fs" % (time.time() - t0), flush=True)
            if st.get("status_str") == "error": print(json.dumps(st.get("messages"))[-1500:])
            ids.remove((name, pid))
import subprocess
for d in glob.glob(os.path.expanduser("~/ComfyUI/output/bezpiecznik/*/")):
    n = os.path.basename(d.rstrip("/"))
    subprocess.run([os.path.expanduser("~/bin/ffmpeg"), "-loglevel", "error", "-y", "-framerate", "24", "-pattern_type", "glob", "-i", d + "f_*.png", "-c:v", "libx264", "-crf", "14", "-pix_fmt", "yuv420p", os.path.join(OUT, n + ".mp4")])
print("done", os.listdir(OUT))
