// One clock owns every animation. Times are seconds, positions are CSS pixels.
export const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
export const smooth=t=>{t=clamp(t,0,1);return t*t*(3-2*t);};
export const DEFAULTS=Object.freeze({amount:35,speed:1,wind:0,windowSnow:false,tree:true,decorated:false});
export function settings(raw={}){return {amount:clamp(Number.isFinite(raw.amount)?raw.amount:35,0,100),speed:clamp(Number.isFinite(raw.speed)?raw.speed:1,.25,2.5),wind:clamp(Number.isFinite(raw.wind)?raw.wind:0,-90,90),windowSnow:raw.windowSnow===true,tree:raw.tree!==false,decorated:raw.decorated===true};}
export function santaPose(t,w,h){const u=clamp(t/8,0,1),s=smooth(u),x=-100+(w+200)*s;const y=h*.27-Math.sin(s*Math.PI)*Math.min(90,h*.15);const slope=-Math.cos(s*Math.PI)*Math.min(90,h*.15)*Math.PI/(w+200);return {x,y:y+Math.sin(t*2.8)*2,angle:Math.atan(slope)*.65+Math.sin(t*2.1)*.018};}
export function projectilePose(a,b,t){const u=clamp(t/.75,0,1);return {x:a.x+(b.x-a.x)*u,y:a.y+(b.y-a.y)*u-Math.sin(Math.PI*u)*Math.min(125,Math.abs(b.x-a.x)*.36)};}
export class World{
  constructor(random=Math.random){this.random=random;this.w=800;this.h=680;this.clock=0;this.config={...DEFAULTS};this.snow=[];this.fx=[];this.gifts=[];this.ground=new Float32Array(110).fill(8);this.cap=new Float32Array(44);this.window=null;this.tree={x:.22,fall:null};this.snowman={x:.72,born:-3};this.santa=null;this.plow=null;this.shot=null;this.deliveries=0;this.exported=0;}
  resize(w,h){const sx=Math.max(1,w)/this.w,sy=Math.max(1,h)/this.h;for(const f of this.snow){f.x*=sx;f.y*=sy;}for(const f of this.fx){f.x*=sx;f.y*=sy;}this.w=Math.max(1,w);this.h=Math.max(1,h);this.groundDirty=true;}
  count(){return Math.round((this.w*this.h/550000)*(this.config.amount/100)**.85*1500);}
  groundAt(x){return this.h-10-this.ground[clamp(Math.round(x/this.w*109),0,109)];}
  deposit(x,mass=1){const i=clamp(Math.round(x/this.w*109),0,109);for(let j=Math.max(0,i-2);j<=Math.min(109,i+2);j++)this.ground[j]=Math.min(33,this.ground[j]+mass*(1-Math.abs(j-i)/3));this.groundDirty=true;}
  flake(){return {x:this.random()*this.w,y:this.random()*this.h,r:.6+this.random()*1.1,v:18+this.random()*31,phase:this.random()*6.28,layer:Math.floor(this.random()*3)};}
  action(name){
    if(name==='santa'){if(this.santa!==null)return false;this.santa={start:this.clock,dropped:false};return true;}
    if(name==='plow'){if(this.plow!==null)return false;this.plow={start:this.clock,x:-100,lastX:-100,load:0,wheel:0};return true;}
    if(name==='tree'){if(this.tree?.fall!==null&&this.tree)return false;this.config.tree=true;this.tree??={x:.22,fall:null};return true;}
    if(name==='decorate'){if(!this.tree||this.tree.fall!==null)return false;this.config.decorated=!this.config.decorated;return true;}
    if(name==='cut'){if(!this.tree||this.tree.fall!==null)return false;this.tree.fall=this.clock;return true;}
    if(name==='snowman'){if(this.snowman||this.shot)return false;this.snowman={x:.72,born:this.clock};return true;}
    if(name==='throw'){if(!this.snowman||this.shot)return false;const target={x:this.snowman.x*this.w,y:this.groundAt(this.snowman.x*this.w)-32};this.shot={start:this.clock,from:{x:Math.max(12,target.x-Math.min(this.w*.55,300)),y:this.groundAt(target.x)-12},to:target};return true;}
    if(name==='gifts'){if(!this.tree||this.tree.fall!==null)return false;for(const offset of [-28,28]){if(this.gifts.length>=5)break;this.gifts.push({x:clamp(this.tree.x*this.w+offset,24,this.w-24)/this.w,start:this.clock,landed:true,opened:null});}return true;}
    return false;
  }
  burst(x,y,color='snow',n=22){const room=180-this.fx.length;for(let i=0;i<Math.min(n,room);i++){const a=this.random()*Math.PI*2,v=25+this.random()*80;this.fx.push({x,y,vx:Math.cos(a)*v,vy:Math.sin(a)*v-30,r:color==='snow'?1.5+this.random()*2:1.6,color,age:0,life:color==='snow'?1.5:1.35});}}
  openGift(i){const g=this.gifts[i];if(!g||!g.landed||g.opened!==null)return false;g.opened=this.clock;for(const [j,color] of ['#f4c65e','#ed8fa8','#7bb8f3'].entries())this.burst(g.x*this.w+(j-1)*30,this.groundAt(g.x*this.w)-70-Math.abs(j-1)*17,color,22);return true;}
  shakeWindow(){if(!this.window)return;for(let i=0;i<this.cap.length;i++){let h=this.cap[i];this.cap[i]=0;for(let j=0;j<Math.min(3,Math.ceil(h));j++)this.fx.push({x:this.window.x+(i+.5)/44*this.window.w,y:this.window.y,vx:0,vy:10,r:1.7,color:'snow',age:0,life:10,deposit:true});}this.fx=this.fx.slice(-180);}
  step(dt){
    dt=clamp(dt,0,.05);this.clock+=dt;const c=this.config,target=Math.min(2100,this.count());while(this.snow.length<target)this.snow.push(this.flake());if(this.snow.length>target)this.snow.length=target;
    const wind=Math.sin(c.wind*Math.PI/180)*95;for(const f of this.snow){const old=f.y;f.y+=f.v*c.speed*dt;f.x+=(wind+Math.sin(this.clock*.6+f.phase)*7)*c.speed*dt;if(f.x<-5)f.x=this.w+4;if(f.x>this.w+5)f.x=-4;
      const box=this.window;if(c.windowSnow&&box&&f.x>box.x&&f.x<box.x+box.w&&old<box.y&&f.y>=box.y){const i=clamp(Math.floor((f.x-box.x)/box.w*44),0,43);this.cap[i]=Math.min(7,this.cap[i]+.2);f.y=-5;f.x=this.random()*this.w;}
      if(f.y>=this.groundAt(f.x)){this.deposit(f.x,.012);f.y=-4;f.x=this.random()*this.w;}
    }
    if(!c.windowSnow)this.cap.fill(0);
    if(this.santa){const t=this.clock-this.santa.start;if(t>=4&&!this.santa.dropped){this.santa.dropped=true;this.deliveries++;const pose=santaPose(t,this.w,this.h);this.gifts.push({x:(.35+this.random()*.3),start:this.clock,dropY:pose.y+22,landed:false,opened:null});if(this.gifts.length>5)this.gifts.shift();}if(t>=8)this.santa=null;}
    for(const g of this.gifts){if(!g.landed&&this.clock-g.start>=3.4)g.landed=true;}
    this.gifts=this.gifts.filter(g=>this.clock-g.start<90&&(g.opened===null||this.clock-g.opened<1.2));
    if(this.plow){const p=this.plow,t=this.clock-p.start,progress=smooth(t/8);p.lastX=p.x;p.x=-95+(this.w+190)*progress;p.wheel+=(p.x-p.lastX)/9;
      for(let i=0;i<110;i++){const x=i/109*this.w;if(x>=p.lastX+25&&x<p.x+25){const take=Math.max(0,this.ground[i]-1);this.ground[i]-=take;p.load+=take;this.groundDirty=true;}}
      if(t>=8){this.exported+=p.load;this.plow=null;}
    }
    if(this.tree?.fall!==null&&this.tree&&this.clock-this.tree.fall>=1.4){this.burst(this.tree.x*this.w,this.groundAt(this.tree.x*this.w));this.tree=null;this.config.tree=false;}
    if(this.shot&&this.clock-this.shot.start>=.75){const p=this.shot.to;this.burst(p.x,p.y,'snow',42);for(let i=0;i<3;i++)this.deposit(p.x+(i-1)*18,1);this.snowman=null;this.shot=null;}
    let kept=0;for(const f of this.fx){f.age+=dt;f.vy+=(f.color==='snow'?210:60)*dt;f.x+=f.vx*dt;f.y+=f.vy*dt;if(f.y>=this.groundAt(f.x)){if(f.deposit||f.color==='snow')this.deposit(f.x,.15);continue;}if(f.age<f.life)this.fx[kept++]=f;}this.fx.length=kept;
  }
}
