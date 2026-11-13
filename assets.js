// SVG sources are fetched once and rasterized at Retina resolution, never per frame.
export async function loadAssets(){
  const base=new URL('./assets/',import.meta.url),response=await fetch(new URL('manifest.json',base));
  if(!response.ok)throw new Error('Не найден реестр изображений');
  const registry=await response.json(),images=new Map(),errors=[];
  await Promise.all(registry.assets.map(async asset=>{try{const image=new Image();image.decoding='async';image.src=new URL(asset.svg,base).href;await image.decode();if(!image.naturalWidth)throw new Error('пустое изображение');const scale=Math.min(2,window.devicePixelRatio||1),bitmap=document.createElement('canvas');bitmap.width=Math.ceil(image.naturalWidth*scale);bitmap.height=Math.ceil(image.naturalHeight*scale);bitmap.getContext('2d').drawImage(image,0,0,bitmap.width,bitmap.height);images.set(asset.id,bitmap);}catch(error){errors.push(asset.id);console.error('SnowPlay asset',asset.id,error);}}));
  return {images,errors,registry};
}
