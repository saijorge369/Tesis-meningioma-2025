import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

const viewer = document.getElementById('viewer');
const statusBox = document.getElementById('status');

const scene = new THREE.Scene();
scene.background = new THREE.Color(0xf3f7ff);

const camera = new THREE.PerspectiveCamera(55, viewer.clientWidth/viewer.clientHeight, 0.1, 2000);
camera.position.set(0,0,140);

const renderer = new THREE.WebGLRenderer({antialias:true,alpha:true});
renderer.setPixelRatio(window.devicePixelRatio);
renderer.setSize(viewer.clientWidth, viewer.clientHeight);
viewer.appendChild(renderer.domElement);

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.autoRotate = true;
controls.autoRotateSpeed = .6;

scene.add(new THREE.AmbientLight(0xffffff,1.8));
const d1 = new THREE.DirectionalLight(0xffffff,2.2);
d1.position.set(90,80,120);
scene.add(d1);

const group = new THREE.Group();
scene.add(group);

let tumorMesh;
let brainMesh;
let skullMesh;
let clipInside = false;

function createBrain(){
  group.clear();

  const skullGeo = new THREE.SphereGeometry(42,64,64);
  skullGeo.scale(1,1.18,.92);

  const brainGeo = new THREE.SphereGeometry(36,64,64);
  brainGeo.scale(1,1.12,.88);

  const csfGeo = new THREE.SphereGeometry(37.2,48,48);
  csfGeo.scale(1,1.13,.89);

  skullMesh = new THREE.Mesh(skullGeo,new THREE.MeshPhysicalMaterial({
    color:0x46d9ff,
    transparent:true,
    opacity:.16,
    roughness:.22,
    metalness:.05,
    transmission:.25,
    side:THREE.DoubleSide
  }));

  const csf = new THREE.Mesh(csfGeo,new THREE.MeshPhysicalMaterial({
    color:0x38bdf8,
    transparent:true,
    opacity:.08,
    roughness:.1
  }));

  brainMesh = new THREE.Mesh(brainGeo,new THREE.MeshPhysicalMaterial({
    color:0xf59e0b,
    transparent:true,
    opacity:.72,
    roughness:.55,
    clearcoat:.3
  }));

  const wmGeo = new THREE.SphereGeometry(24,48,48);
  wmGeo.scale(1,1.08,.84);

  const wm = new THREE.Mesh(wmGeo,new THREE.MeshPhysicalMaterial({
    color:0xa78bfa,
    transparent:true,
    opacity:.44
  }));

  group.add(skullMesh);
  group.add(csf);
  group.add(brainMesh);
  group.add(wm);

  addTumor();

  status('Cerebro virtual generado. Puedes rotarlo 360° y navegar dentro.');
}

function addTumor(){
  if(tumorMesh) group.remove(tumorMesh);

  const rx = Number(document.getElementById('roiX').value);
  const ry = Number(document.getElementById('roiY').value);
  const rz = Number(document.getElementById('roiZ').value);
  const radius = Number(document.getElementById('tumorRadius').value);

  const tumorGeo = new THREE.SphereGeometry(radius,42,42);

  tumorMesh = new THREE.Mesh(tumorGeo,new THREE.MeshPhysicalMaterial({
    color:0xef4444,
    emissive:0x991b1b,
    transparent:true,
    opacity:.88,
    roughness:.32
  }));

  tumorMesh.position.set(rx,ry,rz);
  group.add(tumorMesh);

  status(`ROI colocado en (${rx}, ${ry}, ${rz}) con radio ${radius}.`);
}

function simulateGrowth(){
  let t = 0;
  const tMax = Number(document.getElementById('tMax').value);
  const dt = Number(document.getElementById('dt').value);
  const alpha = Number(document.getElementById('alpha').value);

  const timer = setInterval(()=>{
    t += dt;
    const growth = 1 + alpha*22;
    tumorMesh.scale.multiplyScalar(growth);
    tumorMesh.rotation.y += .03;

    const volume = ((4/3)*Math.PI*Math.pow(tumorMesh.geometry.parameters.radius*tumorMesh.scale.x,3)).toFixed(2);

    status(`Simulación activa | t=${t.toFixed(1)} meses | Volumen estimado=${volume} voxels³`);

    if(t>=tMax){
      clearInterval(timer);
      status('Simulación finalizada.');
    }
  },120);
}

function applyClipping(){
  const cx = Number(document.getElementById('clipX').value);
  const cy = Number(document.getElementById('clipY').value);
  const cz = Number(document.getElementById('clipZ').value);

  renderer.clippingPlanes = [
    new THREE.Plane(new THREE.Vector3(-1,0,0),cx),
    new THREE.Plane(new THREE.Vector3(0,-1,0),cy),
    new THREE.Plane(new THREE.Vector3(0,0,-1),cz)
  ];
}

function toggleInside(){
  clipInside = !clipInside;
  if(clipInside){
    camera.position.set(0,0,8);
    controls.autoRotate = false;
    status('Modo navegación interna activado.');
  }else{
    camera.position.set(0,0,140);
    controls.autoRotate = true;
    status('Vista externa restaurada.');
  }
}

function status(msg){
  statusBox.textContent = msg;
}

window.addEventListener('resize',()=>{
  camera.aspect = viewer.clientWidth/viewer.clientHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(viewer.clientWidth, viewer.clientHeight);
});

renderer.localClippingEnabled = true;

['clipX','clipY','clipZ'].forEach(id=>{
  document.getElementById(id).addEventListener('input',applyClipping);
});

['roiX','roiY','roiZ','tumorRadius'].forEach(id=>{
  document.getElementById(id).addEventListener('input',addTumor);
});

document.getElementById('btnGenerate').onclick = createBrain;
document.getElementById('btnPlaceTumor').onclick = addTumor;
document.getElementById('btnSimulate').onclick = simulateGrowth;
document.getElementById('btnToggleInside').onclick = toggleInside;
document.getElementById('btnResetView').onclick = ()=>{
  camera.position.set(0,0,140);
  controls.target.set(0,0,0);
  controls.update();
};

document.getElementById('btnExport').onclick = ()=>{
  const data = {
    roi:{
      x:document.getElementById('roiX').value,
      y:document.getElementById('roiY').value,
      z:document.getElementById('roiZ').value,
      radius:document.getElementById('tumorRadius').value
    },
    simulation:{
      tMax:document.getElementById('tMax').value,
      dt:document.getElementById('dt').value,
      m0:document.getElementById('m0').value,
      alpha:document.getElementById('alpha').value
    }
  };

  const blob = new Blob([JSON.stringify(data,null,2)],{type:'application/json'});
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = 'menin2026_config.json';
  a.click();
};

function animate(){
  requestAnimationFrame(animate);
  controls.update();
  renderer.render(scene,camera);
}

createBrain();
applyClipping();
animate();
