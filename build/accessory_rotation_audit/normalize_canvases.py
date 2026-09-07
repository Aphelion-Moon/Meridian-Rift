import math, re
from pathlib import Path
from PIL import Image, PngImagePlugin
BASE = Path('modular_nova/master_files/icons/mob/sprite_accessory')
SPECS = [(str(BASE / name), str(BASE / name), 32, 48, 'tall') for name in ['ears_big.dmi', 'horns_big.dmi', 'halo.dmi', 'moogle_pom.dmi']]
SPECS += [(str(BASE / 'moth_fluff.dmi'), str(BASE / 'moth_fluff.dmi'), 32, 32, 'crop')]
SPECS += [(f'icons/mob/human/species/moth/{name}.dmi', str(BASE / f'{name}.dmi'), 32, 32, 'crop') for name in ['moth_antennae', 'moth_markings']]
SPECS += [('icons/mob/human/fish_features.dmi', str(BASE / 'fish_tails.dmi'), 38, 32, 'fish')]
SPECS += [('icons/mob/human/species/alien/tail_xenomorph_queen.dmi', str(BASE / 'tail_xenomorph_queen.dmi'), 64, 96, 'queen')]

def frames(path):
    image = Image.open(path)
    desc = image.info['Description']
    w = int(re.search(r'width = (\d+)', desc)[1]); h = int(re.search(r'height = (\d+)', desc)[1])
    index = 0; result = []
    for block in re.split(r'(?m)^state = ', desc)[1:]:
        name = block.splitlines()[0].strip('"')
        dirs = re.search(r'dirs = (\d+)', block); count = re.search(r'frames = (\d+)', block)
        for _ in range((int(dirs[1]) if dirs else 1) * (int(count[1]) if count else 1)):
            x = index % (image.width // w) * w; y = index // (image.width // w) * h
            result.append((name, image.crop((x,y,x+w,y+h)).convert('RGBA')))
            index += 1
    return desc, w, h, result

def pixels(image, ox, oy):
    return {(x+ox, image.height-1-y+oy): image.getpixel((x,y)) for y in range(image.height) for x in range(image.width) if image.getpixel((x,y))[3]}

total = 0
for src, dst, nw, nh, kind in SPECS:
    desc, ow, oh, old_frames = frames(src)
    backup = Path('build/accessory_rotation_audit') / ('original_' + Path(dst).name)
    if backup.exists():
        raise RuntimeError(f'Backup already exists: {backup}')
    backup.write_bytes(Path(src).read_bytes())
    new_frames = []
    for name, old in old_frames:
        old_offset = (0,0); new_offset = (0,0); shift = (0,0)
        if kind == 'tall':
            shift = (0,8); new_offset = (0,-8)
        elif kind == 'queen':
            old_offset = (-16,0); new_offset = (-16,-32); shift = (0,32)
        elif kind == 'fish':
            old_x = -3 if '_long_' in name else -2 if '_chonky_' in name else 0
            old_offset = (old_x,0); new_offset = (-3,0); shift = (old_x+3,0)
        new = Image.new('RGBA', (nw,nh))
        new.paste(old, (shift[0], nh-oh-shift[1]))
        assert pixels(old,*old_offset) == pixels(new,*new_offset), (src,name,'visible pixel or standing placement changed')
        new_frames.append((name,new))
    cols = math.ceil(math.sqrt(len(new_frames)*nh/nw))
    sheet = Image.new('RGBA',(cols*nw,math.ceil(len(new_frames)/cols)*nh))
    for i, (_, frame) in enumerate(new_frames):
        sheet.paste(frame,(i%cols*nw,i//cols*nh))
    new_desc = re.sub(r'width = \d+', f'width = {nw}', desc, count=1)
    new_desc = re.sub(r'height = \d+', f'height = {nh}', new_desc, count=1)
    info = PngImagePlugin.PngInfo(); info.add_text('Description',new_desc,zip=True)
    sheet.save(dst,format='PNG',pnginfo=info,optimize=True)
    saved_desc, sw, sh, saved_frames = frames(dst)
    assert saved_desc == new_desc and (sw,sh)==(nw,nh)
    assert len(saved_frames)==len(new_frames)
    for (a, af), (b, bf) in zip(new_frames,saved_frames):
        assert a==b and af.tobytes()==bf.tobytes()
    print(f'{dst}: {ow}x{oh} -> {nw}x{nh}; {len(new_frames)} frames, pixels/placement/metadata verified')
    total += len(new_frames)
print(f'TOTAL {total} frames verified')
