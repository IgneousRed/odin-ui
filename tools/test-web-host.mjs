import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

// Execute the real inline host, including event registration order. The linked
// browser smoke check separately exercises Emscripten's actual GLFW listeners.
const html = readFileSync('examples/showcase/index.html', 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
const handlers = {window: [], canvas: []};
const canvas = {
  addEventListener(type, fn, capture = false) { handlers.canvas.push({type, fn, capture}); },
  focus() {},
};
const status = {hidden: false};
const errors = [];
let nextFrame;
let glfwCalls = 0;
let held = false;
const GLFW = {
  onKeydown(event) { glfwCalls++; held = true; if (['Tab', 'Backspace'].includes(event.key)) event.preventDefault(); },
  onKeyPress() { glfwCalls++; },
  onKeyup() { glfwCalls++; held = false; },
  onBlur() { held = false; },
};
const window = {
  addEventListener(type, fn, capture = false) { handlers.window.push({type, fn, capture}); },
  removeEventListener(type, fn, capture = false) {
    const index = handlers.window.findIndex(handler => handler.type === type && handler.fn === fn && handler.capture === capture);
    if (index >= 0) handlers.window.splice(index, 1);
  },
};
const context = vm.createContext({
  console: {log() {}, error(error) { errors.push(error); }},
  document: {getElementById: id => id === 'canvas' ? canvas : status},
  window, GLFW,
  odin: {WasmMemoryInterface: class {setIntSize() {}}, setupDefaultImports: () => ({})},
  requestAnimationFrame(fn) { nextFrame = fn; },
  wasmExports: {_start() {}, ui_start() {
    for (const [type, fn] of [['keydown', GLFW.onKeydown], ['keypress', GLFW.onKeyPress], ['keyup', GLFW.onKeyup]]) {
      window.addEventListener(type, fn, true);
    }
  }, ui_frame() {}},
});
vm.runInContext(script, context);
function dispatch(key, shiftKey = false, target = canvas, type = 'keydown') {
  let stopped = false;
  let prevented = false;
  const event = {key, shiftKey, target,
    stopImmediatePropagation() { stopped = true; },
    preventDefault() { prevented = true; },
  };
  for (const handler of handlers.window) {
    if (handler.type === type && handler.capture) {
      handler.fn(event);
      if (stopped) break;
    }
  }
  if (!stopped && target === canvas) {
    for (const handler of handlers.canvas) {
      if (handler.type === type) {
        handler.fn(event);
        if (stopped) break;
      }
    }
  }
  return {stopped, prevented};
}
context.Module.onRuntimeInitialized();
assert.equal(status.hidden, true);
assert.equal(typeof nextFrame, 'function');
assert.deepEqual(dispatch('Tab'), {stopped: true, prevented: false});
assert.deepEqual(dispatch('Tab', true), {stopped: true, prevented: false});
assert.equal(glfwCalls, 0);
for (const key of ['Backspace', 'ArrowLeft', 'ArrowRight']) {
  assert.deepEqual(dispatch(key), {stopped: false, prevented: true});
}
assert.deepEqual(dispatch('x'), {stopped: false, prevented: false});
const insideCalls = glfwCalls;
for (const key of ['Tab', 'Backspace', 'Enter', ' ', 'x']) {
  for (const type of ['keydown', 'keypress', 'keyup']) {
    assert.deepEqual(dispatch(key, false, {}, type), {stopped: false, prevented: false});
  }
}
assert.equal(glfwCalls, insideCalls, 'Outside controls must not reach GLFW keyboard callbacks');
dispatch('Shift');
assert.equal(held, true);
dispatch('', false, canvas, 'blur');
assert.equal(held, false, 'Canvas blur releases held GLFW keys');
context.wasmExports.ui_frame = () => { throw new Error('frame failed'); };
const frame = nextFrame;
nextFrame = undefined;
frame();
assert.equal(status.hidden, false);
assert.equal(status.textContent, 'Unable to start Odin UI.');
assert.equal(nextFrame, undefined, 'A failed frame must stop scheduling');
assert.equal(errors.length, 1);

let library;
vm.runInNewContext(readFileSync('examples/showcase/odin-library.js', 'utf8'), {
  addToLibrary(value) { library = value; },
  Module: {odinImports: {odin_env: {
    write: (...args) => args.join(','), rand_bytes: (...args) => args.join(','),
  }}},
});
assert.equal(library.write(1, 2, 3), '1,2,3');
assert.equal(library.rand_bytes(4, 5), '4,5');
console.log('Web host checks passed: keyboard routing, frame failure, and Odin import forwarding.');
