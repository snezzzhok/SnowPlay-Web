'use strict';
let state, config, token, saveTimer, saving=null, commandBusy=false;
let pendingChanges={};
let lastDiagnostic='';
const byId=id=>document.getElementById(id);
const ranges=['intensity','snowSpeed','windAngle','accumulationRate','garlandSag','bulbSize','bulbBrightness'];
const toggles=['windowSnow','garlandLights','garlandTwinkle'];
const selects=['treeSize','treeStar','treeBalls','treeGarland','treeToy1','treeToy2','treeToy3','bulbColor'];
const labels={focus:'Focus',balanced:'Balanced',play:'Play'};
function showMessage(text){byId('message').textContent=text;}
function format(key,value){
 if(key==='bulbBrightness')return Math.round(value*100)+'%';
 if(key==='bulbSize')return Math.round(value)+' pt';
 if(key==='intensity')return Math.round(value*100)+'%';
 if(['snowSpeed','snowSize','accumulationRate'].includes(key))return value.toFixed(2).replace(/0+$/,'').replace(/\.$/,'')+'×';
 if(['garlandSag','groundHeight'].includes(key))return Math.round(value)+' pt';
 return Math.abs(value)<1?'Down':`${value<0?'Left':'Right'} ${Math.abs(Math.round(value))}°`;
}
function tab(id,focus=false){
 if(!['snow','tree','snowman','duel','garlands','stories','decorations'].includes(id))id='snow';
 for(const button of document.querySelectorAll('[data-tab]')){const selected=button.dataset.tab===id;button.setAttribute('aria-selected',String(selected));button.tabIndex=selected?0:-1;byId(button.dataset.tab).hidden=!selected;if(selected&&focus)button.focus();}
 try{localStorage.setItem('snowplay.native.tab',id);}catch{}
}
for(const b of document.querySelectorAll('[data-tab]'))b.addEventListener('click',()=>tab(b.dataset.tab));
document.querySelector('.living-tabs').addEventListener('keydown',e=>{const buttons=[...document.querySelectorAll('[data-tab]')],i=buttons.indexOf(document.activeElement);if(i<0)return;const j=e.key==='ArrowRight'?(i+1)%buttons.length:e.key==='ArrowLeft'?(i+buttons.length-1)%buttons.length:e.key==='Home'?0:e.key==='End'?buttons.length-1:null;if(j!==null){e.preventDefault();tab(buttons[j].dataset.tab,true);}});
try{tab(localStorage.getItem('snowplay.native.tab')||'snow');}catch{tab('snow');}
function renderDirection(){
 if(!config)return;
 const angle=config.windAngle*Math.PI/180,u={x:Math.sin(angle),y:Math.cos(angle)},tip={x:180+115*u.x,y:60+115*u.y},end={x:tip.x-14*u.x,y:tip.y-14*u.y},back={x:end.x-12*u.x,y:end.y-12*u.y},normal={x:u.y*6,y:-u.x*6};
 byId('wind-arrow').setAttribute('x2',end.x);byId('wind-arrow').setAttribute('y2',end.y);
 byId('wind-head').setAttribute('d',`M${back.x+normal.x} ${back.y+normal.y} L${end.x} ${end.y} L${back.x-normal.x} ${back.y-normal.y}`);
 for(const id of ['wind-handle','wind-dot']){byId(id).setAttribute('cx',tip.x);byId(id).setAttribute('cy',tip.y);}
 byId('wind-control').setAttribute('aria-valuenow',Math.round(config.windAngle));byId('wind-control').setAttribute('aria-valuetext',format('windAngle',config.windAngle));
}
function render(){
 if(!config)return;
 if((state.diagnostic||'')!==lastDiagnostic){lastDiagnostic=state.diagnostic||'';showMessage(lastDiagnostic);}
 byId('connection').textContent=state.systemPaused?'Sleeping':state.paused?'Paused':'Connected';byId('connection').classList.toggle('online',!state.systemPaused);
 for(const key of ranges){const input=byId(key);input.disabled=commandBusy;if(document.activeElement!==input)input.value=config[key];byId(key+'-value').textContent=format(key,config[key]);}
 for(const key of toggles){byId(key).checked=config[key];byId(key).disabled=commandBusy;}
 for(const key of selects){const input=byId(key);input.disabled=commandBusy||!!state.living?.busy;input.value=config[key];for(const card of document.querySelectorAll(`[data-choice="${key}"]`)){const selected=card.dataset.value===input.value;card.setAttribute('aria-checked',String(selected));card.tabIndex=selected?0:-1;card.disabled=input.disabled;}}
 const living=state.living||{},game=living.duel||{},dueling=!!game.phase,focus=config.mode==='focus',reduced=config.reducedMotion||state.reducedMotionActive;
 byId('restricted').hidden=!focus&&!reduced;byId('restricted-text').textContent=focus?'Switch to Play for interactions.':'Reduce Motion is on.';byId('restricted').querySelector('button').hidden=!focus;
 byId('pause').textContent=state.paused?'Resume':config.snow?'Pause':'Start snow';byId('pause').disabled=commandBusy;
 for(const b of document.querySelectorAll('[data-action]')){
  const action=b.dataset.action,exit=['exit-duel','cancel-story','done','permission','focus','balanced','play'].includes(action),interactive=!exit&&!['shake-windows','remove-hats','reset-ornaments'].includes(action);
  b.disabled=commandBusy||(!exit&&interactive&&(state.paused||state.systemPaused||focus||reduced||living.busy));
  if(action==='remove-garland')b.disabled=commandBusy;
  if(action==='drop-gift')b.disabled=b.disabled||!!state.deliveryState?.giftActive;
  if(action==='duel-fire')b.disabled=commandBusy||game.phase!=='playerAim';
  if(action==='start-duel')b.disabled=commandBusy||dueling||living.busy||focus||reduced||state.paused;
  if(['move-snowmen','remove-snowman'].includes(action))b.disabled=b.disabled||(state.sculpting?.snowmen||0)===0;
  if(action==='snowballs')b.disabled=b.disabled||(state.sculpting?.snowmen||0)>=5;
  if(action==='tree')b.disabled=b.disabled||config.tree;
  if(['tree-gifts','ornaments','remove-tree'].includes(action))b.disabled=b.disabled||!config.tree;
 }
 for(const b of document.querySelectorAll('.mode-row button'))b.classList.toggle('active',b.dataset.action===config.mode);
 byId('tree-label').textContent=config.tree?'Tree placed':'Place tree';byId('remove-tree').hidden=!config.tree;
 byId('editor').hidden=state.editor==='none';
 byId('editor-help').textContent=({tree:'Click to place your tree. Esc to cancel.',snowballPlay:'Sweep snow, grab a ball, flick and release. Esc to finish.',snowmen:'Drag any snowman. Esc to finish.',snow:config.automaticSnowman?'Choose a spot. Esc to cancel.':'Drag the shovel to roll three snowballs. Esc to finish.',ornaments:'Drag ornaments onto the tree.',garland:'Click to place one anchor. Esc to cancel.',garlandDelete:'Choose a whole garland. Esc to cancel.',garlandWindow:'Click a window’s top edge.',hat:'Click a Dock icon.'})[state.editor]||'Click Done to finish.';
 byId('yeti-status').textContent=living.activity?.kind?living.activity.result||({feed:'Drag the snowball to Yeti.',dodge:'Move out of the circle.',surprise:'Here comes a surprise…'})[living.activity.kind]:living.automaticSnowman?'Gathering snow…':(state.characters||[]).length?'Yeti is playing.':'';
 byId('duel-controls').hidden=!dueling;
 if(dueling){byId('player-hp').value=game.playerHP;byId('yeti-hp').value=game.yetiHP;byId('duel-status').textContent=game.obscured?'Clear the play area':game.phase==='playerAim'?`Your turn · ${game.secondsLeft.toFixed(1)}s`:({victory:'You win!',defeat:'Yeti wins!',introduction:'Ready?',yetiPrepare:'Yeti’s turn',yetiFlight:'Yeti’s turn',playerFlight:'Snowball away',reaction:'Nice shot'})[game.phase]||'';}
 byId('sculpt-progress').textContent=`${state.sculpting?.snowmen||0}/5 snowmen${state.editor==='snow'?' · '+(state.sculpting?.balls||0)+'/3 balls':''}`;
 byId('stop-story').hidden=!living.busy;
 byId('permission').hidden=!!state.accessibility;
 const shake=document.querySelector('[data-action="shake-windows"]');shake.hidden=!config.windowSnow;

 renderDirection();renderStories();if(window.renderStickers)renderStickers();
}
async function request(path,body){const r=await fetch(path,body===undefined?{cache:'no-store'}:{method:'POST',headers:{'Content-Type':'application/json','X-SnowPlay-Token':token},body:JSON.stringify(body)});if(!r.ok){let error;try{error=await r.json();}catch{}throw new Error(error?.error||'Error '+r.status);}return r.json();}
async function refresh(){if(saving||commandBusy||Object.keys(pendingChanges).length)return;try{const fresh=await request('/api/state');if(saving||commandBusy||Object.keys(pendingChanges).length)return;state=fresh;config=state.config;token=state.sessionToken;render();}catch(e){byId('connection').textContent='Disconnected';showMessage('Open SnowPlay from the menu bar. '+e.message);}}
function edited(key,value){if(!config)return;config[key]=value;pendingChanges[key]=value;render();clearTimeout(saveTimer);saveTimer=setTimeout(()=>flush().catch(e=>showMessage(e.message)),180);}
async function flush(){clearTimeout(saveTimer);while(saving||Object.keys(pendingChanges).length){if(saving){await saving;continue;}const changes=pendingChanges;pendingChanges={};const snapshot={...config,...changes};const task=(async()=>{try{const fresh=await request('/api/config',snapshot);state=fresh;config={...fresh.config,...pendingChanges};render();}catch(e){pendingChanges={...changes,...pendingChanges};throw e;}})();saving=task;try{await task;}finally{if(saving===task)saving=null;}}}
async function action(name,extra={}){if(!config||commandBusy)return;commandBusy=true;render();try{await flush();state=await request('/api/action',{action:name,...extra});config=state.config;pendingChanges={};showMessage(state.diagnostic||({tree:'Click to choose a spot.',snowballs:'Drag the shovel through the snow.',clean:'Snowplow on its way.','drop-gift':'Gift incoming.','remove-tree':'Removing your tree.','remove-snowman':'Yeti is making a snowball.','reset-settings':'Settings reset.',done:'Done.'})[name]||'');}catch(e){showMessage('Couldn’t complete that: '+e.message);}finally{commandBusy=false;render();}}
for(const key of ranges)byId(key).addEventListener('input',e=>edited(key,Number(e.target.value)));
for(const key of toggles)byId(key).addEventListener('change',e=>edited(key,e.target.checked));
for(const key of selects)byId(key).addEventListener('change',e=>edited(key,e.target.value));
for(const b of document.querySelectorAll('[data-action]'))b.addEventListener('click',()=>action(b.dataset.action,b.dataset.action==='remove-garland-strand'?{id:byId('garland-target').value}:{}));
byId('pause').addEventListener('click',async()=>{if(!state||commandBusy)return;try{if(!config.snow){edited('snow',true);await flush();if(state.paused)await action('resume');return;}await action(state.paused?'resume':'pause');}catch(e){showMessage(e.message);}});
const windControl=byId('wind-control');let windPointer=null;
function setDirection(degrees){if(!config)return;const value=Math.max(-90,Math.min(90,Math.round(degrees)));if(config.windStrength<0.6){config.windStrength=0.6;pendingChanges.windStrength=0.6;}edited('windAngle',value);}
function directionAt(clientX,clientY){const r=byId('wind-scene').getBoundingClientRect();return Math.atan2((clientX-r.left)*360/r.width-180,Math.max(0,(clientY-r.top)*225/r.height-60))*180/Math.PI;}
windControl.addEventListener('pointerdown',e=>{if(!config||commandBusy||e.button!==0)return;e.preventDefault();windPointer=e.pointerId;windControl.setPointerCapture(e.pointerId);setDirection(directionAt(e.clientX,e.clientY));});
windControl.addEventListener('pointermove',e=>{if(e.pointerId===windPointer)setDirection(directionAt(e.clientX,e.clientY));});
function finishWind(e){if(e.pointerId!==windPointer)return;windPointer=null;if(windControl.hasPointerCapture(e.pointerId))windControl.releasePointerCapture(e.pointerId);flush().catch(error=>showMessage(error.message));}
windControl.addEventListener('pointerup',finishWind);windControl.addEventListener('pointercancel',finishWind);windControl.addEventListener('lostpointercapture',()=>windPointer=null);
windControl.addEventListener('keydown',e=>{if(!config||commandBusy)return;let value;if(e.key==='ArrowLeft')value=config.windAngle-(e.shiftKey?15:5);else if(e.key==='ArrowRight')value=config.windAngle+(e.shiftKey?15:5);else if(e.key==='Home')value=-90;else if(e.key==='End')value=90;else if(['ArrowDown','ArrowUp','0'].includes(e.key))value=0;else return;e.preventDefault();setDirection(value);});

function choicePreview(key,value){
 const preview=document.createElement('span');preview.className='choice-preview';preview.setAttribute('aria-hidden','true');
 const img=(id,cls='')=>{const image=new Image();image.src='/assets/'+id;image.alt='';image.className=cls;preview.append(image);};
 if(value==='none'){preview.classList.add('empty-preview');preview.textContent='—';return preview;}
 if(key==='bulbColor'){
  preview.classList.add('strand-preview');const colors=value==='warm'?['gold','gold','gold','gold']:value==='ice'?['blue','purple','blue','purple']:['red','green','gold','blue'];
  for(const color of colors)img('fairy_bulb_'+color,'lamp '+color);
 }else if(key.startsWith('treeToy'))img('tree_charm_'+value);
 else{preview.classList.add('tree-preview');if(key==='treeSize')preview.classList.add('size-'+value);img('tree_bare','base-tree');
  if(key!=='treeSize'){const prefix={treeGarland:'tree_string_',treeStar:'tree_topper_',treeBalls:'tree_balls_'}[key];img(prefix+value,'tree-overlay');}
 }
 return preview;
}
for(const key of selects){
 const select=byId(key),group=document.querySelector(`[data-options="${key}"]`);
 for(const option of select.options){const card=document.createElement('button');card.type='button';card.className='option-card';card.dataset.choice=key;card.dataset.value=option.value;card.setAttribute('role','radio');card.setAttribute('aria-checked','false');
  card.append(choicePreview(key,option.value));const label=document.createElement('span');label.textContent=option.textContent;card.append(label);
  card.addEventListener('click',()=>{select.value=option.value;select.dispatchEvent(new Event('change',{bubbles:true}));});group.append(card);
 }
 group.addEventListener('keydown',event=>{const cards=[...group.children],i=cards.indexOf(document.activeElement);if(i<0)return;const next=event.key==='ArrowRight'||event.key==='ArrowDown'?(i+1)%cards.length:event.key==='ArrowLeft'||event.key==='ArrowUp'?(i+cards.length-1)%cards.length:event.key==='Home'?0:event.key==='End'?cards.length-1:null;if(next!==null){event.preventDefault();if(!cards[next].disabled){cards[next].click();cards[next].focus();}}});
}

refresh();setInterval(()=>{if(!document.hidden)refresh();},500);document.addEventListener('visibilitychange',()=>{if(!document.hidden)refresh();});

function updateStorySetting(key,value){edited('stories',{...config.stories,[key]:value});}
function renderStories(){
 const world=state.christmasStories||{},playing=world.active||{},settings=config.stories||{};
 byId('storiesEnabled').checked=!!settings.enabled;
 for(const [id,key] of [['storiesSounds','sounds'],['storiesCreation','allowSnowmanCreation'],['storiesKeep','keepDecorations'],['storiesBattery','pauseOnBattery'],['storiesFullscreen','pauseInFullscreen']]){byId(id).checked=!!settings[key];byId(id).disabled=commandBusy;}
 byId('storiesMotion').checked=config.reducedMotion;byId('storiesMotion').disabled=commandBusy;
 for(const b of document.querySelectorAll('[data-frequency]')){const selected=b.dataset.frequency===settings.frequency;b.classList.toggle('active',selected);b.setAttribute('aria-pressed',String(selected));b.disabled=commandBusy;}
 byId('story-playing').hidden=!playing.id;byId('story-playing-title').textContent=playing.id?'Playing · '+playing.title:'';byId('story-stop').disabled=commandBusy||!playing.id;
 byId('story-developer').hidden=!world.developerMode;
 const zone=settings.reservedZones||[];if(document.activeElement!==byId('story-icon-zone'))byId('story-icon-zone').value=zone.length===0?'none':zone.length===1&&zone[0].screen==='all'&&zone[0].rect.width===.16?(zone[0].rect.x===0?'left':'right'):'custom';
 const list=byId('story-cards');
 for(const story of world.catalogue||[]){
  let card=document.getElementById('story-'+story.id);
  if(!card){
   card=document.createElement('article');card.id='story-'+story.id;card.className='story-card';const icon=new Image();icon.src='/assets/'+story.icon;icon.alt='';
   const copy=document.createElement('div'),title=document.createElement('h4'),description=document.createElement('p'),reason=document.createElement('small');title.textContent=story.title;description.textContent=story.description;reason.className='story-reason';copy.append(title,description,reason);
   const controls=document.createElement('div');controls.className='story-card-actions';const play=document.createElement('button');play.type='button';play.className='story-play';play.textContent='Play';play.setAttribute('aria-label','Play '+story.title);play.addEventListener('click',()=>{const choice=byId('story-variant').value;action('story-play',{id:story.id,...(world.developerMode&&choice!=='auto'?{variant:Number(choice)}:{})});});
   const auto=document.createElement('label');auto.className='story-auto';const check=document.createElement('input');check.type='checkbox';check.setAttribute('aria-label','Automatic '+story.title);check.addEventListener('change',()=>{const ids=new Set(config.stories.enabledStories);if(check.checked)ids.add(story.id);else ids.delete(story.id);updateStorySetting('enabledStories',[...ids]);});auto.append(check,document.createTextNode('Auto'));controls.append(play,auto);card.append(icon,copy,controls);list.append(card);
  }
  const button=card.querySelector('.story-play'),current=playing.id===story.id;button.textContent=current?'Playing':'Play';button.disabled=commandBusy||!story.available||!!playing.id;card.querySelector('.story-reason').textContent=current?'':story.reason||'';card.querySelector('input').checked=story.automaticAllowed!==false&&(settings.enabledStories||[]).includes(story.id);card.querySelector('input').disabled=commandBusy||story.automaticAllowed===false;card.querySelector('.story-auto').lastChild.textContent=story.automaticAllowed===false?'Manual':'Auto';
 }
 byId('story-random').disabled=commandBusy||!(world.catalogue||[]).some(s=>s.available);
}
byId('storiesEnabled').addEventListener('change',e=>updateStorySetting('enabled',e.target.checked));
for(const [id,key] of [['storiesSounds','sounds'],['storiesCreation','allowSnowmanCreation'],['storiesKeep','keepDecorations'],['storiesBattery','pauseOnBattery'],['storiesFullscreen','pauseInFullscreen']])byId(id).addEventListener('change',e=>updateStorySetting(key,e.target.checked));
byId('storiesMotion').addEventListener('change',e=>edited('reducedMotion',e.target.checked));
for(const b of document.querySelectorAll('[data-frequency]'))b.addEventListener('click',()=>updateStorySetting('frequency',b.dataset.frequency));
byId('story-icon-zone').addEventListener('change',e=>updateStorySetting('reservedZones',e.target.value==='none'?[]:[{screen:'all',rect:{x:e.target.value==='left'?0:.84,y:0,width:.16,height:1}}]));
byId('story-random').addEventListener('click',()=>action('story-random'));byId('story-stop').addEventListener('click',()=>action('story-stop'));
