# Local generation for film v2: Flux.2 start frames (optionally guided by a reference frame from the
# storyboard animation) and MiniMax H3 image-to-video clips, both through the local ComfyUI.
# Usage:  python gen.py frames [name ...]     -> frames/<name>_s<seed>.png
#         python gen.py clips  [name ...]     -> clips/<name>_s<seed>.mp4   (start frame = frames/<FRAME>)
import json, os, shutil, subprocess, sys, time, urllib.request, glob

URL = "http://127.0.0.1:8188"
HERE = os.path.dirname(os.path.abspath(__file__))
CIN = os.path.expanduser("~/ComfyUI/input/bz2")
COUT = os.path.expanduser("~/ComfyUI/output/bz2")
W, H = 1344, 768
NEG = "cgi, 3d render, illustration, cartoon, painting, oversaturated, hdr, text, letters, watermark, logo"
LOOK = ("Real photograph from a body-worn camera at eye level: ultra wide-angle 14mm lens, very wide field of view "
        "(about 120 degrees) showing a lot of the surroundings, slight barrel distortion at the edges, shot at night "
        "at high ISO, underexposed, natural sensor noise, realistic materials and imperfections, lived-in Polish "
        "apartment, no text, no logos.")

# name: (reference frame from the animation or None, prompt)
FRAMES = {
 "room":   ("a_011.jpg", "First-person view from a bed in a dark Polish apartment bedroom at 3 a.m. Horizontal venetian "
            "blinds on the window let in thin stripes of cold streetlight, a small warm bedside lamp glows on a cluttered "
            "desk, crumpled duvet edge in the foreground. " + LOOK),
 "phone":  (None, "First-person point of view looking down at my own two hands holding a smartphone in portrait "
            "orientation, lying in bed in a dark bedroom at night, duvet and pillow around, the hands lit only by the "
            "screen. The whole phone screen is one solid flat uniform pure chroma-key green colour (#00FF00), no "
            "interface, no reflections on it. Thumb of the right hand resting near the lower edge of the screen. " + LOOK),
 "blinds": ("a_041.jpg", "Dark bedroom at night seen from inside, a window with closed horizontal venetian blinds, thin "
            "cold light leaking between the slats, the silhouette of a desk chair in front of it. " + LOOK),
 "floor":  ("a_086.jpg", "A smartphone lying face down on a dark wooden floor of an apartment hallway at night, a thin "
            "cold beam of light falls through a door gap across the floor. Low angle. " + LOOK),
 "stairs": ("a_058.jpg", "First-person view walking down a dark concrete stairwell of a Polish apartment block at night, "
            "lit only by a phone flashlight held in the right hand, worn green painted walls, metal handrail, steps "
            "going down into darkness. " + LOOK),
 "door":   ("a_061.jpg", "A heavy grey steel shelter door in the basement of a Polish apartment block, a blank white "
            "sign plate on the door, bare concrete walls, cold dim light, first-person view, a hand reaching for the "
            "lever handle. " + LOOK),
 "tap":    ("a_029.jpg", "First-person view in a dark small kitchen at night, my hand turning on a chrome kitchen tap "
            "over a steel sink, no water comes out, window blinds behind, cold dim light. " + LOOK),
 "table":  ("a_053.jpg", "Top-down view of a kitchen table at night lit by a small flashlight lying on it: two plastic "
            "water bottles, an insulin pen in a small blue cooling pouch, a few sheets of paper in a clear plastic "
            "sleeve, a power bank, a pack of pills, a folded warm jacket, hands packing them into a backpack. "
            "No passport, no flags, no emblems. " + LOOK),
 "cpr":    ("a_069.jpg", "Basement shelter at night lit only by a small battery lantern on the floor, on the wall the "
            "large shadow of a person kneeling and doing chest compressions, an old wooden table, concrete walls. "
            "Faces not visible. " + LOOK),
 "shelter":("a_063.jpg", "Basement shelter of a Polish apartment block at night, several people in winter jackets "
            "sitting on benches along the wall seen mostly as dark silhouettes against a small warm battery lantern "
            "on the floor, concrete walls, pipes. " + LOOK),
 "phone2": (None, "First-person point of view standing in a dark small kitchen at night, looking down at a smartphone "
            "held in my right hand in portrait orientation, thumb over the screen, sink and tap blurred behind. The whole "
            "phone screen is one solid flat uniform pure chroma-key green colour (#00FF00), no interface. " + LOOK),
 "phone3": (None, "First-person point of view sitting on a bench in a dark concrete basement shelter at night, both hands "
            "holding a smartphone in portrait orientation close to the chest, a small battery lantern on the floor "
            "far behind, out of focus. The whole phone screen is one solid flat uniform pure chroma-key green colour "
            "(#00FF00), no interface. " + LOOK),
 "sos":    (None, "First-person view in a pitch-dark stairwell of an apartment block at night, my hand holding a "
            "smartphone up with its rear flashlight on, the bright flashlight beam lighting dust in the air and the "
            "concrete wall. The phone screen faces me and is one solid flat uniform pure chroma-key green colour "
            "(#00FF00). " + LOOK),
}

# name: (start frame file, prompt, length in frames @24 fps, last frame file or None)
STYLE = ("Ultra wide-angle body-camera first-person footage (very wide field of view, slight fisheye). Handheld first-person footage from the eyes of a frightened person, natural small hand tremor and breathing "
         "sway, realistic physics, photorealistic, dark, natural sensor grain. No cuts, no text, no people's faces.")
CLIPS = {
 "room":   ("room_s1.png", "Timeline:\n[0s-3s] The view drifts slightly as the person lifts their head from the pillow, "
            "the stripes of light on the blinds stay still, the lamp glows steadily.\n\n" + STYLE +
            "\n\nAudio: quiet room tone, a distant air-raid siren wailing outside.", 73, None),
 "lamp":   ("room_s1.png", "Timeline:\n[0s-1s] Stillness, the warm lamp glows.\n[1s-1.6s] The lamp flickers twice and "
            "goes out, the room drops into darkness, only the cold stripes of streetlight through the blinds remain, "
            "then the streetlight outside also dies.\n[1.6s-3s] Near-total darkness.\n\n" + STYLE +
            "\n\nAudio: electrical buzz, click, silence.", 73, None),
 "phone":  ("phone_s1.png", "Timeline:\n[0s-3s] The hands hold the phone, the right thumb taps the lower part of the "
            "green screen several times, the hands tremble slightly. The screen stays solid flat green the whole time "
            "and the phone stays fully in frame.\n\n" + STYLE + "\n\nAudio: fast breathing, screen taps.", 73, None),
 "blinds": ("blinds_s1.png", "Timeline:\n[0s-0.8s] Stillness.\n[0.8s-2s] From outside, a bright flashlight beam sweeps "
            "across the closed blinds from left to right, its light slices between the slats into the room, the view "
            "jerks back in fright.\n[2s-3s] Darkness again.\n\n" + STYLE + "\n\nAudio: footsteps and shouting far "
            "outside, siren.", 73, None),
 "floor":  ("floor_s1.png", "Timeline:\n[0s-3s] Static low view, the phone lies face down on the floor, dust drifts in "
            "the beam of light, the light flickers once.\n\nLocked-off camera, photorealistic, dark, natural grain, "
            "no people.\n\nAudio: muffled siren through the walls.", 73, None),
 "stairs": ("stairs_s1.png", "Timeline:\n[0s-3s] The person hurries down the stairs, the flashlight beam bounces "
            "with each step, the handrail slides past on the right.\n\n" + STYLE +
            "\n\nAudio: fast footsteps on concrete, breathing, echo.", 73, None),
 "door":   ("door_s1.png", "Timeline:\n[0s-3s] The hand grabs the lever handle and pulls the heavy steel door open, "
            "warm light from inside spills out onto the concrete.\n\n" + STYLE +
            "\n\nAudio: metal clunk, heavy door creak.", 73, None),
 "tap":    ("tap_s1.png", "Timeline:\n[0s-3s] The hand turns the tap fully open, nothing comes out, only a short "
            "dry gurgle, the hand turns it again.\n\n" + STYLE + "\n\nAudio: dry pipe gurgle, silence.", 73, None),
 "table":  ("table_s1.png", "Timeline:\n[0s-3s] Hands quickly pack the water bottles, the insulin pen and the "
            "documents into the backpack, the flashlight on the table lights them.\n\n" + STYLE +
            "\n\nAudio: rustling, zipper.", 73, None),
 "cpr":    ("cpr_s1.png", "Timeline:\n[0s-3s] The shadow on the wall keeps doing steady fast chest compressions, two "
            "per second, the lantern light flickers slightly.\n\nLocked-off camera, photorealistic, dark, natural "
            "grain, no faces.\n\nAudio: rhythmic compressions, someone counting quietly.", 73, None),
 "shelter":("shelter_s1.png", "Timeline:\n[0s-3s] The people sit still and wait, one of them pulls a jacket tighter, "
            "the lantern light trembles.\n\n" + STYLE + "\n\nAudio: muffled distant explosions, a child whimpering.",
            73, None),
 "phone2": ("phone2_s1.png", "Timeline:\n[0s-3s] The hand holds the phone, the thumb taps and scrolls the "
            "lower part of the green screen, the hand trembles slightly. The screen stays solid flat green the whole "
            "time and the phone stays fully in frame.\n\n" + STYLE + "\n\nAudio: breathing, taps.", 73, None),
 "phone3": ("phone3_s1.png", "Timeline:\n[0s-3s] The hands hold the phone still, the thumb taps the screen "
            "twice, slight breathing movement. The screen stays solid flat green the whole time and the phone stays "
            "fully in frame.\n\n" + STYLE + "\n\nAudio: muffled voices, breathing.", 73, None),
 "sos":    ("sos_s1.png", "Timeline:\n[0s-3s] The phone flashlight blinks the SOS pattern, three short, three long, "
            "three short flashes, lighting the stairwell walls in bursts, the hand trembles. The screen facing the "
            "viewer stays solid flat green.\n\n" + STYLE + "\n\nAudio: breathing, distant siren.", 73, None),
}

def post(g):
    r = urllib.request.urlopen(urllib.request.Request(URL + "/prompt", json.dumps({"prompt": g}).encode(),
                                                      {"Content-Type": "application/json"}))
    return json.load(r)["prompt_id"]

def wait(jobs):
    t0 = time.time()
    while jobs:
        time.sleep(5)
        for name, pid in list(jobs):
            h = json.load(urllib.request.urlopen(f"{URL}/history/{pid}"))
            if pid in h:
                st = h[pid].get("status", {})
                print(name, st.get("status_str"), "%.0fs" % (time.time() - t0), flush=True)
                if st.get("status_str") == "error":
                    print(json.dumps(st.get("messages"))[-1500:])
                jobs.remove((name, pid))

def flux_ref(name, ref, prompt, seed):
    g = {
     "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "flux2-dev-nvfp4.safetensors", "weight_dtype": "default"}},
     "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": "mistral_3_small_flux2_fp4_mixed.safetensors", "type": "flux2"}},
     "3": {"class_type": "VAELoader", "inputs": {"vae_name": "flux2-vae.safetensors"}},
     "4": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["2", 0]}},
     "5": {"class_type": "CLIPTextEncode", "inputs": {"text": NEG, "clip": ["2", 0]}},
     "6": {"class_type": "EmptyFlux2LatentImage", "inputs": {"width": W, "height": H, "batch_size": 1}},
     "10": {"class_type": "FluxGuidance", "inputs": {"conditioning": ["4", 0], "guidance": 4.0}},
     "7": {"class_type": "KSampler", "inputs": {"model": ["1", 0], "seed": seed, "steps": 28, "cfg": 1.0,
           "sampler_name": "euler", "scheduler": "simple", "positive": ["10", 0], "negative": ["5", 0],
           "latent_image": ["6", 0], "denoise": 1.0}},
     "8": {"class_type": "VAEDecode", "inputs": {"samples": ["7", 0], "vae": ["3", 0]}},
     "9": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": f"bz2/f_{name}_s{seed}"}},
    }
    if ref:
        shutil.copy(os.path.join(HERE, "ref/anim", ref), os.path.join(CIN, ref))
        g["20"] = {"class_type": "LoadImage", "inputs": {"image": f"bz2/{ref}"}}
        g["21"] = {"class_type": "ImageScale", "inputs": {"image": ["20", 0], "upscale_method": "lanczos",
                   "width": W, "height": H, "crop": "center"}}
        g["22"] = {"class_type": "VAEEncode", "inputs": {"pixels": ["21", 0], "vae": ["3", 0]}}
        g["23"] = {"class_type": "ReferenceLatent", "inputs": {"conditioning": ["4", 0], "latent": ["22", 0]}}
        g["10"]["inputs"]["conditioning"] = ["23", 0]
    return post(g)

def h3(name, img, prompt, seed, length, last):
    shutil.copy(os.path.join(HERE, "frames", img), os.path.join(CIN, img))
    g = {
     "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "minimax_h3_fl2va_pruned_int8_convrot.safetensors", "weight_dtype": "default"}},
     "2": {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["1", 0], "lora_name": "minimax_h3_fl2v_turbo_8step_v1.0_comfyui_bf16.safetensors", "strength_model": 1.0}},
     "3": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors", "type": "minimax", "device": "default"}},
     "4": {"class_type": "VAELoader", "inputs": {"vae_name": "minimax_h3_video_vae_fp16.safetensors"}},
     "6": {"class_type": "LoadImage", "inputs": {"image": f"bz2/{img}"}},
     "7": {"class_type": "ImageScale", "inputs": {"image": ["6", 0], "upscale_method": "lanczos", "width": W, "height": H, "crop": "center"}},
     "8": {"class_type": "MiniMaxH3ImageToVideo", "inputs": {"clip": ["3", 0], "vae": ["4", 0], "first_frame": ["7", 0],
           "prompt": prompt, "width": W, "height": H, "length": length}},
     "9": {"class_type": "RandomNoise", "inputs": {"noise_seed": seed}},
     "10": {"class_type": "KSamplerSelect", "inputs": {"sampler_name": "res_multistep"}},
     "11": {"class_type": "BasicScheduler", "inputs": {"model": ["2", 0], "scheduler": "simple", "steps": 8, "denoise": 1.0}},
     "12": {"class_type": "BasicGuider", "inputs": {"model": ["2", 0], "conditioning": ["8", 0]}},
     "13": {"class_type": "SamplerCustomAdvanced", "inputs": {"noise": ["9", 0], "guider": ["12", 0], "sampler": ["10", 0],
            "sigmas": ["11", 0], "latent_image": ["8", 1]}},
     "14": {"class_type": "VAEDecode", "inputs": {"samples": ["13", 0], "vae": ["4", 0]}},
     "15": {"class_type": "SaveImage", "inputs": {"images": ["14", 0], "filename_prefix": f"bz2/c_{name}_s{seed}/f"}},
     # H3 generates sound with the picture: keep it as foley
     "16a": {"class_type": "VAELoader", "inputs": {"vae_name": "minimax_h3_audio_vae_fp32.safetensors"}},
     "17a": {"class_type": "VAEDecodeAudio", "inputs": {"samples": ["13", 0], "vae": ["16a", 0]}},
     "18a": {"class_type": "SaveAudio", "inputs": {"audio": ["17a", 0], "filename_prefix": f"bz2/c_{name}_s{seed}/a"}},
    }
    if last:
        shutil.copy(os.path.join(HERE, "frames", last), os.path.join(CIN, last))
        g["16"] = {"class_type": "LoadImage", "inputs": {"image": f"bz2/{last}"}}
        g["17"] = {"class_type": "ImageScale", "inputs": {"image": ["16", 0], "upscale_method": "lanczos", "width": W, "height": H, "crop": "center"}}
        g["8"]["inputs"]["last_frame"] = ["17", 0]
    return post(g)

if __name__ == "__main__":
    os.makedirs(CIN, exist_ok=True)
    mode, names = sys.argv[1], sys.argv[2:]
    seeds = [int(x) for x in os.environ.get("SEEDS", "1").split(",")]
    jobs = []
    if mode == "frames":
        os.makedirs(os.path.join(HERE, "frames"), exist_ok=True)
        for n in names or FRAMES:
            for s in seeds:
                jobs.append((f"{n}_s{s}", flux_ref(n, FRAMES[n][0], FRAMES[n][1], s)))
        wait(list(jobs))
        for n, _ in jobs:
            src = sorted(glob.glob(f"{COUT}/f_{n}_*.png"), key=os.path.getmtime)[-1]
            shutil.copy(src, os.path.join(HERE, "frames", n + ".png"))
    else:
        os.makedirs(os.path.join(HERE, "clips"), exist_ok=True)
        for n in names or CLIPS:
            img, p, length, last = CLIPS[n]
            for s in seeds:
                jobs.append((f"{n}_s{s}", h3(n, img, p, s, length, last)))
        wait(list(jobs))
        for n, _ in jobs:
            d = f"{COUT}/c_{n}/"
            subprocess.run([os.path.expanduser("~/bin/ffmpeg"), "-loglevel", "error", "-y", "-framerate", "24",
                            "-pattern_type", "glob", "-i", d + "f_*.png", "-c:v", "libx264", "-crf", "12",
                            "-pix_fmt", "yuv420p", os.path.join(HERE, "clips", n + ".mp4")])
            for au in glob.glob(d + "a_*.flac"):
                shutil.copy(au, os.path.join(HERE, "clips", n + ".flac"))
    print("done", [n for n, _ in jobs])
