import {clamp,smooth,santaPose,projectilePose} from './scene.js';
export class Renderer{
  constructor(canvas,assets,{batched=false}={}){this.canvas=canvas;this.ctx=canvas.getContext('2d',{alpha:true});this.assets=assets;this.batched=batched;this.dpr=1;this.groundPath=null;}
  resize(w,h,dpr){this.dpr=Math.min(dpr||1,2);this.canvas.width=Math.round(w*this.dpr);this.canvas.height=Math.round(h*this.dpr);this.groundPath=null;}
  image(id,x,y,w,h=w,angle=0,alpha=1,ax=.5,ay=.5){const img=this.assets.get(id);if(!img)return;const c=this.ctx;c.save();c.globalAlpha=alpha;c.translate(x,y);if(angle)c.rotate(angle);c.drawImage(img,-w*ax,-h*ay,w,h);c.restore();}
  circle(x,y,r,color,alpha=1){const c=this.ctx;c.globalAlpha=alpha;c.fillStyle=color;c.beginPath();c.arc(x,y,r,0,Math.PI*2);c.fill();c.globalAlpha=1;}
  draw(world){const c=this.ctx,w=world.w,h=world.h;c.setTransform(this.dpr,0,0,this.dpr,0,0);c.clearRect(0,0,w,h);
    // Keep the faster individual circle fills, grouping only canvas state changes.
    // Large compound paths and bitmap dots were both slower on the test Mac.
    if(this.batched){c.fillStyle='#f2f8fa';for(let layer=0;layer<3;layer++){c.globalAlpha=.35+layer*.25;for(const f of world.snow)if(f.layer===layer){c.beginPath();c.arc(f.x,f.y,f.r,0,Math.PI*2);c.fill();}}c.globalAlpha=1;}
    else for(const f of world.snow)this.circle(f.x,f.y,f.r,'#f2f8fa',.35+f.layer*.25);
    if(!this.groundPath||world.groundDirty){const p=new Path2D();p.moveTo(0,h);p.lineTo(0,world.groundAt(0));for(let i=0;i<110;i++){const x=i/109*w,y=world.groundAt(x);p.lineTo(x,y);}p.lineTo(w,h);p.closePath();this.groundPath=p;world.groundDirty=false;}
    c.fillStyle='#c3d6df';c.fill(this.groundPath);c.save();c.translate(0,-2);c.fillStyle='#eff7fa';c.fill(this.groundPath);c.restore();
    if(world.window&&world.config.windowSnow){const box=world.window;c.fillStyle='#eff7fa';c.beginPath();c.moveTo(box.x,box.y);for(let i=0;i<44;i++)c.lineTo(box.x+(i+.5)/44*box.w,box.y-world.cap[i]);c.lineTo(box.x+box.w,box.y);c.closePath();c.fill();}
    if(world.tree){const t=world.tree,size=clamp(h*.31,130,220),x=t.x*w,y=world.groundAt(x)+3,age=t.fall===null?0:world.clock-t.fall,angle=t.fall===null?Math.sin(world.clock*.7)*.006:Math.pow(clamp(age/1.1,0,1),2)*1.62,alpha=age>1.1?1-(age-1.1)/.3:1;
      c.save();c.translate(x,y);c.rotate(angle);this.image('tree_trunk',0,0,size,size,0,alpha,.5,.94);this.image('tree_bare',0,0,size,size,0,alpha,.5,.94);if(world.config.decorated){this.image('tree_balls_gold',0,0,size,size,0,alpha,.5,.94);this.image('tree_string_multi',0,0,size,size,0,alpha*(.88+.12*Math.sin(world.clock)),.5,.94);this.image('tree_topper_gold',0,0,size,size,0,alpha,.5,.94);}c.restore();}
    if(world.snowman){const s=world.snowman,x=s.x*w,y=world.groundAt(x),age=world.clock-s.born,size=clamp(h*.21,85,128),bob=age>1.5?Math.sin(world.clock*1.4)*.008:0;
      if(age>=1.5)this.image('snowman_complete',x,y,size,size,bob,1,.5,.96);
      else for(let i=0;i<3;i++){const u=smooth((age-i*.35)/.55),r=[size*.15,size*.115,size*.082][i],yy=y-[size*.15,size*.39,size*.58][i]-Math.sin(Math.PI*u)*15;this.image(['snowball_large','snowball_medium','snowball_small'][i],x+(1-u)*(i-1)*50,yy,r*2.4,r*2.4,0,u);}
    }
    for(const g of world.gifts){const age=world.clock-g.start,x=g.x*w,ground=world.groundAt(x)-4,land=smooth(age/3.4),y=g.landed?ground:g.dropY+(ground-g.dropY)*land,opened=g.opened!==null,fade=opened?clamp(1-(world.clock-g.opened)/1.2,0,1):1;
      if(!g.landed){const swing=Math.sin(age*2.6)*.065;this.image('gift_parachute',x+Math.sin(age*2.6)*4*(1-land),y,58,58,swing,1,.5,.84);}else this.image(opened?'gift_open':'gift_closed',x,y,42,42,opened?-.1:0,fade,.5,.84);}
    if(world.santa){const t=world.clock-world.santa.start,p=santaPose(t,w,h),sw=clamp(w*.16,94,160),sh=sw*230/330;c.save();c.translate(p.x,p.y);c.rotate(p.angle);this.image('magic_trail',-sw*.7,sh*.1,sw*.7,sw*.7*110/256,0,.45);this.image('gift_sack',0,Math.sin(t*2.4)*1.1,sw,sh);this.image('santa_character',0,Math.sin(t*2.4)*.5,sw,sh);this.image('sleigh',0,0,sw,sh);c.restore();}
    if(world.plow){const p=world.plow,sw=104,sh=sw*230/320,base=h-12,cy=base-sh*.92+Math.sin(p.wheel)*.7;
      this.image('snowplow_body',p.x,cy,sw,sh,0,1,.5,0);this.image('snowplow_blade',p.x,cy,sw,sh,0,1,.5,0);this.image('snowplow_beacon',p.x,cy,sw,sh,0,.75+Math.sin(world.clock*5)*.2,.5,0);
      const img=this.assets.get('snowplow_wheels');if(img){for(const sx of [70,183]){const wx=p.x+(sx+35-160)/320*sw,wy=cy+176/230*sh;c.save();c.translate(wx,wy);c.rotate(p.wheel);c.drawImage(img,sx/320*img.width,141/230*img.height,70/320*img.width,70/230*img.height,-11.4,-11.4,22.8,22.8);c.restore();}}
      const load=Math.min(17,p.load*.08);if(load>0){c.fillStyle='#e9f5f8';c.beginPath();c.ellipse(p.x+41,base-3,10+load*.45,4+load,0,Math.PI,Math.PI*2);c.fill();}
    }
    if(world.shot){const p=projectilePose(world.shot.from,world.shot.to,world.clock-world.shot.start);this.image('snowball_small',p.x,p.y,13);}
    for(const f of world.fx)this.circle(f.x,f.y,f.r,f.color==='snow'?'#f6fbff':f.color,clamp(1-f.age/f.life,0,1));
  }
}
