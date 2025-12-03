var demo = function(i){
 var s,e,a=this,t=i.getAttribute("data-framerepeats"),r=t?JSON.parse(t):{};
 return a.element=i,a.mode=i.getAttribute("data-mode")||"standard",a.width=(e=i,(t=getComputedStyle(e).width)?parseFloat(t.replace("px","")):e.clientWidth||0),a.fps=parseInt(i.getAttribute("data-fps"),10)||24,a.replayDelay=parseInt(i.getAttribute("data-replaydelay"),10)||0,a.frameDuration=1e3/this.fps+1,a.bindedRender=this.render.bind(this),a.previewImage=this.element.style.backgroundImage,a.spriteImage=i.getAttribute("data-image"),s=a.spriteImage,new Promise(function(e,t){var i=new Image;i.onload=e,i.onerror=t,i.src=s}).then(function(e){var t=e.target,e="auto"===(e=i.getAttribute("data-frames"))?Math.round(t.width/a.width):parseInt(e,10)||60;});
};
