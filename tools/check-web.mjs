import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {once} from 'node:events';
import {readFile, mkdtemp, rm} from 'node:fs/promises';
import {createServer} from 'node:http';
import {resolve} from 'node:path';

// Chromium's debugging pipe avoids a package dependency and a public debug port.
// The only served files are the actual linked showcase, on an ephemeral loopback port.
const root = resolve(process.argv[2] ?? 'binaries/web');
const directory = await mkdtemp(resolve('.work/web-browser-'));
const browser = spawn(process.env.CHROMIUM_BIN ?? 'chromium', [
  '--headless', '--no-first-run', '--no-default-browser-check',
  '--disable-background-timer-throttling', '--disable-renderer-backgrounding',
  '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
  `--user-data-dir=${directory}`, '--remote-debugging-pipe', 'about:blank',
], {stdio: ['ignore', 'ignore', 'pipe', 'pipe', 'pipe']});
const pending = new Map();
const errors = [];
let sequence = 0;
let buffered = '';
let browserLog = '';
browser.stderr.on('data', chunk => { browserLog += chunk; });
const stopped = once(browser, 'exit').catch(() => {});
function fail(error) {
  for (const request of pending.values()) request.reject(error);
  pending.clear();
}
browser.on('error', error => fail(new Error(`Unable to launch Chromium; set CHROMIUM_BIN to an installed executable. ${error.message}`)));
browser.on('exit', (code, signal) => fail(new Error(`Chromium exited (${code ?? signal}). ${browserLog}`)));
browser.stdio[3].on('error', fail);
browser.stdio[4].setEncoding('utf8');
browser.stdio[4].on('data', chunk => {
  buffered += chunk;
  let end;
  while ((end = buffered.indexOf('\0')) >= 0) {
    const message = JSON.parse(buffered.slice(0, end));
    buffered = buffered.slice(end + 1);
    if (message.id) {
      const request = pending.get(message.id);
      if (!request) continue;
      pending.delete(message.id);
      if (message.error) request.reject(new Error(JSON.stringify(message.error)));
      else request.resolve(message.result);
    } else if (message.method === 'Runtime.exceptionThrown') {
      errors.push(message.params.exceptionDetails.exception?.description ?? message.params.exceptionDetails.text);
    } else if (message.method === 'Runtime.consoleAPICalled' && message.params.type === 'error') {
      errors.push(message.params.args.map(arg => arg.description ?? arg.value).join(' '));
    }
  }
});
function send(method, params = {}, sessionId) {
  const id = ++sequence;
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      pending.delete(id);
      reject(new Error(`Timed out: ${method} ${params.expression?.slice(0, 100) ?? ""}. ${browserLog}`));
    }, 15000);
    pending.set(id, {
      resolve(value) { clearTimeout(timeout); resolve(value); },
      reject(error) { clearTimeout(timeout); reject(error); },
    });
    browser.stdio[3].write(JSON.stringify({id, method, params, sessionId}) + '\0');
  });
}
const types = {'index.html': 'text/html', 'showcase.js': 'text/javascript',
  'odin.js': 'text/javascript', 'showcase.wasm': 'application/wasm'};
const server = createServer(async (request, response) => {
  const name = request.url === '/' ? 'index.html' : request.url.slice(1);
  if (!Object.hasOwn(types, name)) { response.writeHead(404).end(); return; }
  try {
    response.writeHead(200, {'Content-Type': types[name]});
    response.end(await readFile(resolve(root, name)));
  } catch { response.destroy(); }
});
try {
  // Attach directly to a fresh target; no existing browser session is touched.
  const {targetId} = await send('Target.createTarget', {url: 'about:blank'});
  const {sessionId} = await send('Target.attachToTarget', {targetId, flatten: true});
  const call = (method, params = {}) => send(method, params, sessionId);
  const evaluate = async expression => {
    const result = await call('Runtime.evaluate', {expression, awaitPromise: true, returnByValue: true});
    if (result.exceptionDetails) throw new Error(result.exceptionDetails.exception?.description ?? result.exceptionDetails.text);
    return result.result.value;
  };
  await call('Runtime.enable');
  await call('Page.bringToFront');
  await call('Emulation.setDeviceMetricsOverride', {width: 800, height: 600, deviceScaleFactor: 1, mobile: false});
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  await call('Page.navigate', {url: `http://127.0.0.1:${server.address().port}/`});
  await evaluate(`new Promise((resolve, reject) => {
    const deadline = performance.now() + 10000;
    function ready() {
      const status = document.getElementById('status');
      if (status?.hidden) return resolve(true);
      if (status?.textContent.includes('Unable') || performance.now() > deadline) return reject(new Error(status?.textContent ?? 'Host did not load'));
      requestAnimationFrame(ready);
    }
    ready();
  })`);
  const snapshot = () => evaluate(`new Promise((resolve, reject) => requestAnimationFrame(() => requestAnimationFrame(() => {
    try {
    const start = wasmExports.ui_smoke_snapshot();
    const bytes = new Uint8Array(wasmExports.memory.buffer);
    let end = start;
    while (bytes[end] !== 0) end++;
    resolve(JSON.parse(new TextDecoder().decode(bytes.subarray(start, end))));
    } catch (error) { reject(error); }
  })))`);
  const mouse = (type, x, y) => call('Input.dispatchMouseEvent', {
    type, x, y, button: type === 'mouseMoved' ? 'none' : 'left',
    buttons: type === 'mousePressed' ? 1 : 0, clickCount: type === 'mouseMoved' ? 0 : 1,
  });
  const center = rect => [rect[0] + rect[2] / 2, rect[1] + rect[3] / 2];
  const click = async rect => {
    const [x, y] = center(rect);
    await mouse('mouseMoved', x, y);
    await mouse('mousePressed', x, y);
    await snapshot();
    await mouse('mouseReleased', x, y);
    return snapshot();
  };
  const key = async (name, code, virtualCode, modifiers = 0) => {
    for (const type of ['keyDown', 'keyUp']) {
      const text = type === 'keyDown' ? (name === 'Enter' ? '\r' : name === ' ' ? ' ' : undefined) : undefined;
      await call('Input.dispatchKeyEvent', {type, key: name, code, windowsVirtualKeyCode: virtualCode, modifiers, text});
      await snapshot();
    }
  };
  console.log('Linked host started; checking pointer input.');
  let state = await snapshot();
  assert.equal(state.clicks, 0);
  assert.equal(state.name, 'Edit me: café');
  state = await click(state.button);
  assert.equal(state.clicks, 1, 'A real pointer click must increment exactly once');
  const [x, y] = center(state.button);
  await mouse('mousePressed', x, y);
  await snapshot();
  await mouse('mouseMoved', 1, 1);
  await snapshot();
  await mouse('mouseReleased', 1, 1);
  state = await snapshot();
  assert.equal(state.clicks, 1, 'Release outside must cancel a click');

  await evaluate(`const focusButton = document.createElement('button');
    focusButton.id = 'smoke-focus'; focusButton.textContent = 'Outside canvas';
    focusButton.style = 'position:fixed;right:0;bottom:0'; document.body.append(focusButton);
    const before = focusButton.cloneNode(true); before.id = 'smoke-before';
    before.style = 'position:fixed;left:0;bottom:0';
    document.body.insertBefore(before, document.getElementById('canvas'));`);
  console.log('Pointer click and outside-release cancellation passed; checking keyboard focus.');
  await key('Tab', 'Tab', 9);
  assert.equal(await evaluate(`document.activeElement.id`), 'smoke-focus', 'Tab must escape the actual GLFW canvas');
  await evaluate(`document.getElementById('canvas').focus()`);
  await key('Tab', 'Tab', 9, 8);
  assert.equal(await evaluate(`document.activeElement.id`), 'smoke-before', 'Shift+Tab must escape the canvas through normal browser navigation');
  console.log('Tab/Shift+Tab passed; checking focus-loss cancellation.');
  await mouse('mousePressed', x, y);
  await snapshot();
  await evaluate(`document.getElementById('smoke-focus').focus()`);
  await snapshot();
  await mouse('mouseReleased', x, y);
  state = await snapshot();
  assert.equal(state.clicks, 1, 'Focus loss during a press must cancel capture');

  console.log('Focus-loss cancellation passed; checking outside-canvas keyboard input.');
  await evaluate(`window.outsideClicks = 0;
    document.getElementById('smoke-focus').addEventListener('click', () => window.outsideClicks++);
    const outside = document.createElement('input'); outside.id = 'smoke-input';
    outside.style = 'position:fixed;right:0;top:0'; document.body.append(outside);`);
  state = await click((await snapshot()).button);
  const outsideCanvasClicks = state.clicks;
  await evaluate(`document.getElementById('smoke-focus').focus()`);
  await key('Enter', 'Enter', 13);
  assert.equal((await snapshot()).clicks, outsideCanvasClicks, 'Outside buttons must not activate the canvas counter');
  assert.equal(await evaluate(`window.outsideClicks`), 1, 'Outside buttons retain ordinary keyboard activation');
  await key(' ', 'Space', 32);
  assert.equal((await snapshot()).clicks, outsideCanvasClicks);
  state = await click((await snapshot()).field);
  const savedName = state.name;
  await evaluate(`{
    const outside = document.getElementById('smoke-input');
    outside.value = 'outside'; outside.focus(); outside.setSelectionRange(7, 7);
  }`);
  await call('Input.dispatchKeyEvent', {type: 'char', text: 'x', unmodifiedText: 'x'});
  assert.equal((await snapshot()).name, savedName, 'Typing outside must not edit the canvas field');
  assert.equal(await evaluate(`document.getElementById('smoke-input').value`), 'outsidex');
  await key('Backspace', 'Backspace', 8);
  assert.equal(await evaluate(`document.getElementById('smoke-input').value`), 'outside', 'Outside Backspace retains its browser default');
  assert.equal((await snapshot()).name, savedName);
  await evaluate(`document.getElementById('smoke-before').focus()`);
  await key('Tab', 'Tab', 9);
  assert.equal(await evaluate(`document.activeElement.id`), 'canvas', 'Outside Tab retains browser navigation');

  await call('Input.dispatchKeyEvent', {type: 'keyDown', key: 'Shift', code: 'ShiftLeft', windowsVirtualKeyCode: 16, modifiers: 8});
  assert.equal(await evaluate(`Boolean(GLFW.active.domKeys[16])`), true, await evaluate(`JSON.stringify({focus: document.activeElement.id, keys: GLFW.active.domKeys})`));
  await evaluate(`document.getElementById('smoke-input').focus()`);
  assert.equal(await evaluate(`Boolean(GLFW.active.domKeys[16])`), false, 'Blur must release keys whose keyup occurs outside');
  await call('Input.dispatchKeyEvent', {type: 'keyUp', key: 'Shift', code: 'ShiftLeft', windowsVirtualKeyCode: 16});

  console.log('Outside-canvas keyboard input passed; checking UTF-8 editing.');
  state = await click(state.field);
  await key('Backspace', 'Backspace', 8);
  state = await snapshot();
  assert.equal(state.name, 'Edit me: caf', 'Backspace must remove the full UTF-8 codepoint');
  await call('Input.dispatchKeyEvent', {type: 'char', text: 'é', unmodifiedText: 'é'});
  state = await snapshot();
  assert.equal(state.name, 'Edit me: café');
  await key('ArrowLeft', 'ArrowLeft', 37);
  await call('Input.dispatchKeyEvent', {type: 'char', text: 'x', unmodifiedText: 'x'});
  state = await snapshot();
  assert.equal(state.name, 'Edit me: cafxé', 'Arrow navigation must preserve UTF-8 insertion boundaries');
  await call('Emulation.setDeviceMetricsOverride', {width: 375, height: 640, deviceScaleFactor: 1, mobile: false});
  state = await snapshot();
  assert.equal(state.width, 375);
  assert.equal(state.height, 640);
  assert.equal(state.clicks, outsideCanvasClicks);
  assert.equal(state.name, 'Edit me: cafxé');
  assert.ok(state.field[0] >= 0 && state.field[0] + state.field[2] <= 375);
  assert.equal(await evaluate(`document.getElementById('status').hidden`), true);
  assert.deepEqual(errors, [], 'Linked host must produce no runtime errors');
  console.log('Linked Chromium smoke passed: startup, click/cancel, Tab/Shift+Tab, focus loss, UTF-8 editing, and resize.');
} finally {
  server.closeAllConnections();
  if (server.listening) await new Promise(resolve => server.close(resolve));
  browser.kill();
  const terminate = setTimeout(() => browser.kill('SIGKILL'), 5000);
  await stopped;
  clearTimeout(terminate);
  await rm(directory, {recursive: true, force: true});
}
