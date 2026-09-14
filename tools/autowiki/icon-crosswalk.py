"""Build review candidates; never authorize replacements from display names alone."""
import argparse,collections,hashlib,json,pathlib,re
from PIL import Image

def normal(value): return re.sub(r'[^a-z0-9]','',value.casefold())
def pixels(path):
 with Image.open(path) as im:
  im=im.convert('RGBA'); im.paste((0,0,0,0),mask=im.getchannel('A').point(lambda x:255 if x==0 else 0))
  return hashlib.sha256(f'{im.width}x{im.height}:'.encode()+im.tobytes()).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('inventory',type=pathlib.Path);p.add_argument('package',type=pathlib.Path);p.add_argument('output',type=pathlib.Path);a=p.parse_args()
 inventory=json.loads(a.inventory.read_text(encoding='utf-8')); entities=[json.loads(l) for l in (a.package/'entity.jsonl').read_text(encoding='utf-8').splitlines()]; index=collections.defaultdict(list)
 for entity in entities:
  for key in {normal(entity['fields']['name']),normal(entity['id'].split('/')[-1])}: index[key].append(entity)
 uses=collections.Counter(x['lt_title'] for x in inventory['uses']); rows=[]
 for f in inventory['files']:
  if f['img_name'].startswith('Autowiki-') or int(f['img_width'])>128 or int(f['img_height'])>128: continue
  candidates=index[normal(pathlib.Path(f['img_name']).stem)]
  item={'filename':f['img_name'],'uses':uses[f['img_name']],'previousSha1':f['img_sha1'],'status':'unmapped','candidates':[]}
  try: old=pixels(f['path'])
  except Exception as e: old=None;item['readError']=type(e).__name__
  for c in candidates:
   icon=c['fields']['icon_file']; iconpath=a.package/'icons'/icon if icon else None
   item['candidates'].append({'entity':c['id'],'name':c['fields']['name'],'icon':icon,'source':c['fields']['icon_source'],'state':c['fields']['icon_state'],'samePixels':bool(iconpath and iconpath.is_file() and pixels(iconpath)==old)})
  if candidates:
   matches=[c for c in item['candidates'] if c['samePixels']]
   item['status']='name-and-pixels-match' if matches else 'name-candidate-needs-review'
  rows.append(item)
 a.output.mkdir(parents=True,exist_ok=False)
 (a.output/'crosswalk.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
 summary={'files':len(rows),'statuses':dict(collections.Counter(x['status'] for x in rows)),'notice':'Candidates only. Display names do not establish canonical identity. Initial renders exclude runtime overlays.'}
 (a.output/'summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8');print(json.dumps(summary))
if __name__=='__main__': main()
