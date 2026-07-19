import {
  WebGLRenderer,
  Scene,
  PerspectiveCamera,
  InstancedMesh,
  PlaneGeometry,
  CircleGeometry,
  MeshBasicMaterial,
  Object3D,
  Color,
  DynamicDrawUsage,
} from 'three';
import type { ConfettiSceneConfig, ConfettiRenderer } from './types';

const BRAND_COLORS = [
  new Color('#ff69d5'), // pink
  new Color('#2c82ff'), // blue
  new Color('#21bf68'), // green
  new Color('#f9b815'), // yellow
];

// A particle pool where each particle has a lifetime.
// life <= 0 means dormant (invisible). life > 0 means alive and fading.
interface ParticlePool {
  positions: Float32Array; // x,y,z per particle
  velocities: Float32Array;
  rotations: Float32Array;
  rotSpeeds: Float32Array;
  phases: Float32Array;
  baseScales: Float32Array;
  life: Float32Array; // 1.0 = just spawned, 0.0 = dead
  maxLife: Float32Array; // total lifetime in seconds
  count: number;
}

function createPool(count: number): ParticlePool {
  return {
    positions: new Float32Array(count * 3),
    velocities: new Float32Array(count * 3),
    rotations: new Float32Array(count * 3),
    rotSpeeds: new Float32Array(count),
    phases: new Float32Array(count),
    baseScales: new Float32Array(count),
    life: new Float32Array(count), // all start at 0 = dormant
    maxLife: new Float32Array(count),
    count,
  };
}

/** Spawn a single particle at a random index from the dormant pool */
function spawnParticle(
  pool: ParticlePool,
  startIdx: number,
  originX: number,
  originY: number,
  spread: number,
  speedMult: number
): boolean {
  // Find a dormant particle starting from startIdx, wrapping around
  for (let attempt = 0; attempt < pool.count; attempt++) {
    const i = (startIdx + attempt) % pool.count;
    if (pool.life[i] > 0) continue; // already alive

    const angle = Math.random() * Math.PI * 2;
    const speed = (0.02 + Math.random() * 0.06) * speedMult;

    const ix = i * 3;
    pool.positions[ix] = originX + (Math.random() - 0.5) * spread;
    pool.positions[ix + 1] = originY + (Math.random() - 0.5) * spread * 0.5;
    pool.positions[ix + 2] = -(0.5 + Math.random() * 7);

    pool.velocities[ix] = Math.cos(angle) * speed;
    pool.velocities[ix + 1] = Math.sin(angle) * speed * 0.8 + 0.02; // slight upward bias
    pool.velocities[ix + 2] = 0;

    pool.rotations[ix] = Math.random() * Math.PI * 2;
    pool.rotations[ix + 1] = Math.random() * Math.PI * 2;
    pool.rotations[ix + 2] = Math.random() * Math.PI * 2;

    pool.rotSpeeds[i] = 0.01 + Math.random() * 0.04;
    pool.phases[i] = Math.random() * Math.PI * 2;
    pool.baseScales[i] = 0.5 + Math.random() * 1.0;
    pool.life[i] = 1.0;
    pool.maxLife[i] = 2.0 + Math.random() * 3.0; // 2-5 seconds lifetime
    return true;
  }
  return false; // pool is full
}

function getParticleCount(): number {
  if (typeof window === 'undefined') return 0;
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return 0;

  const isLowEnd =
    (navigator.hardwareConcurrency && navigator.hardwareConcurrency <= 4) ||
    window.innerWidth < 768;

  return isLowEnd ? 120 : 350;
}

export function createConfettiRenderer(config: ConfettiSceneConfig): ConfettiRenderer {
  const { canvas, backgroundColor, scrollProgress } = config;
  const particleCount = config.particleCount || getParticleCount();

  if (particleCount === 0) {
    return { init: () => {}, destroy: () => {}, triggerBurst: () => {} };
  }

  let renderer: WebGLRenderer | null = null;
  let scene: Scene | null = null;
  let camera: PerspectiveCamera | null = null;
  let meshes: InstancedMesh[] = [];
  let destroyed = false;
  let prevScroll = 0;
  let prevTime = 0;
  let spawnCursor = 0; // round-robin index for finding dormant particles

  // Scroll velocity tracking
  let scrollVelocity = 0;
  let scrollVelocitySmoothed = 0;
  let lastSpawnTime = 0;

  let frameCount = 0;
  let lastFpsCheck = 0;

  const dummy = new Object3D();
  const ZERO_SCALE = 0.0001;

  // 3 shape groups, each with its own pool
  const rectCount = Math.ceil(particleCount / 3);
  const circleCount = Math.ceil(particleCount / 3);
  const ribbonCount = particleCount - rectCount - circleCount;
  const pools: ParticlePool[] = [
    createPool(rectCount),
    createPool(circleCount),
    createPool(ribbonCount),
  ];

  function createMesh(shapeType: number, count: number): InstancedMesh {
    let geometry;
    if (shapeType === 0) geometry = new PlaneGeometry(0.4, 0.22);
    else if (shapeType === 1) geometry = new CircleGeometry(0.15, 8);
    else geometry = new PlaneGeometry(0.6, 0.08);

    const material = new MeshBasicMaterial({
      transparent: true,
      opacity: 1.0,
      depthWrite: false,
    });

    const mesh = new InstancedMesh(geometry, material, count);
    mesh.instanceMatrix.setUsage(DynamicDrawUsage);
    // Particles start parked off-screen at z=-100, so the bounding sphere
    // three.js computes once (and caches) sits far beyond the far plane and the
    // whole mesh gets frustum-culled forever — even after particles spawn into
    // view. Particles move every frame, so per-mesh culling buys nothing anyway.
    mesh.frustumCulled = false;

    // Set colors and hide all particles initially
    for (let i = 0; i < count; i++) {
      mesh.setColorAt(i, BRAND_COLORS[i % BRAND_COLORS.length]);
      dummy.position.set(0, 0, -100); // off-screen
      dummy.scale.set(ZERO_SCALE, ZERO_SCALE, ZERO_SCALE);
      dummy.updateMatrix();
      mesh.setMatrixAt(i, dummy.matrix);
    }
    mesh.instanceColor!.needsUpdate = true;
    mesh.instanceMatrix.needsUpdate = true;

    return mesh;
  }

  /** Spawn N particles distributed across the 3 shape pools */
  function spawnBatch(
    count: number,
    originX: number,
    originY: number,
    spread: number,
    speedMult: number
  ) {
    const perPool = Math.ceil(count / 3);
    for (let p = 0; p < 3; p++) {
      for (let n = 0; n < perPool; n++) {
        spawnParticle(pools[p], spawnCursor, originX, originY, spread, speedMult);
        spawnCursor = (spawnCursor + 1) % pools[p].count;
      }
    }
  }

  function tick(time: number) {
    if (destroyed || !renderer || !scene || !camera) return;

    const dtMs = prevTime === 0 ? 16 : Math.min(time - prevTime, 50);
    const dt = dtMs / 1000; // seconds
    prevTime = time;

    // --- Scroll velocity ---
    // scrollProgress is 0-1 for the whole page. Convert to pixel-scale velocity
    // by multiplying by total scrollable height.
    const scroll = scrollProgress.get();
    const scrollDelta = scroll - prevScroll;
    prevScroll = scroll;

    const scrollableHeight = document.documentElement.scrollHeight - window.innerHeight;
    const pixelDelta = Math.abs(scrollDelta) * scrollableHeight;
    const pixelVelocity = pixelDelta / Math.max(dt, 0.001); // px/sec

    scrollVelocity = pixelVelocity;
    scrollVelocitySmoothed += (scrollVelocity - scrollVelocitySmoothed) * 0.2;

    // --- Scroll-driven spawning ---
    // Normal scroll ~300-800 px/s, fast flick ~2000+ px/s
    // Map to 0-15 particles per frame
    const normalizedSpeed = Math.min(scrollVelocitySmoothed / 600, 1); // 0-1
    const spawnRate = normalizedSpeed * 15;
    const timeSinceLastSpawn = time - lastSpawnTime;

    if (spawnRate > 0.2 && timeSinceLastSpawn > 25) {
      const toSpawn = Math.max(1, Math.round(spawnRate));
      spawnBatch(
        toSpawn,
        (Math.random() - 0.5) * (8 + normalizedSpeed * 12),
        (Math.random() - 0.5) * 8,
        3 + normalizedSpeed * 8,
        0.5 + normalizedSpeed * 2
      );
      lastSpawnTime = time;
    }

    // --- Update particles ---
    for (let s = 0; s < 3; s++) {
      const pool = pools[s];
      const mesh = meshes[s];
      if (!mesh) continue;

      for (let i = 0; i < pool.count; i++) {
        if (pool.life[i] <= 0) {
          // Dormant — keep hidden
          dummy.position.set(0, 0, -100);
          dummy.scale.set(ZERO_SCALE, ZERO_SCALE, ZERO_SCALE);
          dummy.updateMatrix();
          mesh.setMatrixAt(i, dummy.matrix);
          continue;
        }

        const ix = i * 3;
        const iy = ix + 1;
        const iz = ix + 2;

        // Age the particle
        pool.life[i] -= dt / pool.maxLife[i];
        const life = Math.max(pool.life[i], 0);

        // Gravity — gentle pull down
        pool.velocities[iy] -= 0.008 * dt;

        // Damping
        pool.velocities[ix] *= 1 - 0.8 * dt;
        pool.velocities[iy] *= 1 - 0.6 * dt;

        // Scroll push — particles move with the scroll direction
        const depth = Math.max(0, -pool.positions[iz]) / 8;
        const parallax = 0.2 + depth * 0.8;
        pool.positions[iy] += scrollDelta * parallax * 40;

        // Wind from scroll speed
        if (scrollVelocitySmoothed > 50) {
          const windDir = Math.sin(pool.phases[i] * 5 + time * 0.001);
          const windNorm = Math.min(scrollVelocitySmoothed / 1000, 1);
          pool.velocities[ix] += windDir * windNorm * 0.08 * dt;
        }

        // Gentle float / drift
        pool.positions[ix] += Math.sin(time * 0.0008 + pool.phases[i]) * 0.15 * dt;
        pool.positions[iy] += Math.cos(time * 0.0006 + pool.phases[i] * 1.7) * 0.08 * dt;

        // Apply velocity
        pool.positions[ix] += pool.velocities[ix] * dtMs;
        pool.positions[iy] += pool.velocities[iy] * dtMs;

        // Tumble
        pool.rotations[ix] += pool.rotSpeeds[i] * dtMs * 0.06;
        pool.rotations[iy] += pool.rotSpeeds[i] * 0.7 * dtMs * 0.06;
        pool.rotations[iz] += pool.rotSpeeds[i] * 0.4 * dtMs * 0.06;

        // Scale: pop in, then fade/shrink out
        // life goes 1.0 → 0.0
        // Scale curve: quick grow at start, hold, then shrink at end
        let scaleT: number;
        if (life > 0.85) {
          // Pop in (life 1.0→0.85)
          scaleT = (1.0 - life) / 0.15; // 0→1
          scaleT = scaleT * scaleT * (3 - 2 * scaleT); // smoothstep
        } else if (life > 0.2) {
          scaleT = 1.0; // full size
        } else {
          // Fade out (life 0.2→0.0)
          scaleT = life / 0.2;
          scaleT = scaleT * scaleT; // ease out
        }

        const finalScale = pool.baseScales[i] * scaleT;

        dummy.position.set(pool.positions[ix], pool.positions[iy], pool.positions[iz]);
        dummy.rotation.set(pool.rotations[ix], pool.rotations[iy], pool.rotations[iz]);
        dummy.scale.set(finalScale, finalScale, finalScale);
        dummy.updateMatrix();
        mesh.setMatrixAt(i, dummy.matrix);

        // Kill if dead
        if (life <= 0) {
          pool.life[i] = 0;
        }
      }

      mesh.instanceMatrix.needsUpdate = true;
    }

    // FPS monitoring — reduce spawn rate if too slow
    frameCount++;
    if (time - lastFpsCheck > 3000) {
      const fps = (frameCount / (time - lastFpsCheck)) * 1000;
      if (fps < 28) {
        // Kill some alive particles to recover
        for (const pool of pools) {
          for (let i = 0; i < pool.count; i += 3) {
            pool.life[i] = 0;
          }
        }
      }
      frameCount = 0;
      lastFpsCheck = time;
    }

    renderer.render(scene, camera);
  }

  function handleResize() {
    if (!renderer || !camera || destroyed) return;
    renderer.setSize(window.innerWidth, window.innerHeight);
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
  }

  function handleVisibility() {
    if (destroyed || !renderer) return;
    if (document.hidden) {
      renderer.setAnimationLoop(null);
    } else {
      prevTime = 0;
      renderer.setAnimationLoop(tick);
    }
  }

  function handleContextLost(e: Event) {
    e.preventDefault();
    if (renderer) renderer.setAnimationLoop(null);
  }

  function handleContextRestored() {
    if (destroyed || !renderer) return;
    prevTime = 0;
    renderer.setAnimationLoop(tick);
  }

  return {
    init() {
      const isLowEnd = window.innerWidth < 768;

      renderer = new WebGLRenderer({
        canvas,
        alpha: true,
        antialias: !isLowEnd,
        powerPreference: isLowEnd ? 'low-power' : 'high-performance',
      });
      renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));
      renderer.setSize(window.innerWidth, window.innerHeight);
      renderer.setClearColor(new Color(backgroundColor), 0);

      scene = new Scene();

      camera = new PerspectiveCamera(60, window.innerWidth / window.innerHeight, 0.1, 50);
      camera.position.set(0, 0, 12);
      camera.lookAt(0, 0, 0);

      meshes = [createMesh(0, rectCount), createMesh(1, circleCount), createMesh(2, ribbonCount)];
      meshes.forEach(m => scene!.add(m));

      window.addEventListener('resize', handleResize);
      document.addEventListener('visibilitychange', handleVisibility);
      canvas.addEventListener('webglcontextlost', handleContextLost);
      canvas.addEventListener('webglcontextrestored', handleContextRestored);

      prevScroll = scrollProgress.get();
      lastFpsCheck = performance.now();
      renderer.setAnimationLoop(tick);
    },

    destroy() {
      destroyed = true;
      if (renderer) {
        renderer.setAnimationLoop(null);
        renderer.dispose();
      }
      meshes.forEach(m => {
        m.geometry.dispose();
        (m.material as MeshBasicMaterial).dispose();
      });
      meshes = [];
      window.removeEventListener('resize', handleResize);
      document.removeEventListener('visibilitychange', handleVisibility);
      canvas.removeEventListener('webglcontextlost', handleContextLost);
      canvas.removeEventListener('webglcontextrestored', handleContextRestored);
      renderer = null;
      scene = null;
      camera = null;
    },

    triggerBurst(intensity = 1.0) {
      // Spawn a burst of particles from the center of the screen
      const count = Math.round(30 * intensity);
      spawnBatch(count, 0, 0, 6 * intensity, 1.0 + intensity * 0.5);
    },
  };
}

export { getParticleCount };
