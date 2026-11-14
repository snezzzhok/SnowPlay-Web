'use strict';
let state, config, token, saveTimer, saving=null, commandBusy=false;
let pendingChanges={};
let lastDiagnostic='';
const byId=id=>document.getElementById(id);
const ranges=['intensity','snowSpeed','windAngle','garlandSag'];
const toggles=['windowSnow','garlandLights','garlandTwinkle'];
const selects=['treeSize','treeStar','treeBalls','treeGarland','treeToy1','treeToy2','treeToy3','bulbColor'];
const labels={focus:'Focus',balanced:'Balanced',play:'Play'};
function showMessage(text){byId('message').textContent=text;}
function format(key,value){
 if(key==='intensity')return Math.round(value*100)+'%';
 if(['snowSpeed','snowSize'].includes(key))return value.toFixed(2).replace(/0+$/,'').replace(/\.$/,'')+'×';
 if(['garlandSag','groundHeight'].includes(key))return Math.round(value)+' pt';
 return Math.abs(value)<1?'Down':`${value<0?'Left':'Right'} ${Math.abs(Math.round(value))}°`;
}
function tab(id,focus=false){
 if(!['snow','tree','snowman','duel','garlands'].includes(id))id='snow';
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
 for(const key of selects){const input=byId(key);input.disabled=commandBusy||!!state.living?.busy;input.value=config[key];}
 const living=state.living||{},game=living.duel||{},dueling=!!game.phase,focus=config.mode==='focus',reduced=config.reducedMotion||state.reducedMotionActive;
 byId('restricted').hidden=!focus&&!reduced;byId('restricted-text').textContent=focus?'Switch to Play for interactions.':'Reduce Motion is on.';byId('restricted').querySelector('button').hidden=!focus;
 byId('pause').textContent=state.paused?'Resume':config.snow?'Pause':'Start snow';byId('pause').disabled=commandBusy;
 for(const b of document.querySelectorAll('[data-action]')){
  const action=b.dataset.action,exit=['exit-duel','cancel-story','done','permission','focus','balanced','play'].includes(action),interactive=!exit&&!['shake-windows','remove-hats','reset-ornaments'].includes(action);
  b.disabled=commandBusy||(!exit&&interactive&&(state.paused||state.systemPaused||focus||reduced||living.busy));
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
 byId('editor-help').textContent=({tree:'Click to place your tree. Esc to cancel.',snowballPlay:'Sweep snow, grab a ball, flick and release. Esc to finish.',snowmen:'Drag any snowman. Esc to finish.',snow:config.automaticSnowman?'Choose a spot. Esc to cancel.':'Drag the shovel to roll three snowballs. Esc to finish.',ornaments:'Drag ornaments onto the tree.',garland:'Click to place anchors.',garlandWindow:'Click a window’s top edge.',hat:'Click a Dock icon.'})[state.editor]||'Click Done to finish.';
 byId('yeti-status').textContent=living.activity?.kind?living.activity.result||({feed:'Drag the snowball to Yeti.',dodge:'Move out of the circle.',surprise:'Here comes a surprise…'})[living.activity.kind]:living.automaticSnowman?'Gathering snow…':(state.characters||[]).length?'Yeti is playing.':'';
 byId('duel-controls').hidden=!dueling;
 if(dueling){byId('player-hp').value=game.playerHP;byId('yeti-hp').value=game.yetiHP;byId('duel-status').textContent=game.obscured?'Clear the play area':game.phase==='playerAim'?`Your turn · ${game.secondsLeft.toFixed(1)}s`:({victory:'You win!',defeat:'Yeti wins!',introduction:'Ready?',yetiPrepare:'Yeti’s turn',yetiFlight:'Yeti’s turn',playerFlight:'Snowball away',reaction:'Nice shot'})[game.phase]||'';}
 byId('sculpt-progress').textContent=`${state.sculpting?.snowmen||0}/5 snowmen${state.editor==='snow'?' · '+(state.sculpting?.balls||0)+'/3 balls':''}`;
 byId('stop-story').hidden=!living.busy;
 byId('permission').hidden=!!state.accessibility;
 const shake=document.querySelector('[data-action="shake-windows"]');shake.hidden=!config.windowSnow;

 const strands=Object.values(config.placements||{}).flatMap(p=>p.extraGarlands||[]),picker=byId('garland-target'),signature=strands.map(s=>s.id).join(',');
 if(picker.dataset.signature!==signature){const old=picker.value;picker.replaceChildren(new Option('Current','active'),...strands.map((s,i)=>new Option('Strand '+(i+1),s.id)));if([...picker.options].some(o=>o.value===old))picker.value=old;picker.dataset.signature=signature;}
 renderDirection();
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
refresh();setInterval(()=>{if(!document.hidden)refresh();},500);document.addEventListener('visibilitychange',()=>{if(!document.hidden)refresh();});
