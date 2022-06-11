-- mlre v1.2.8 @sonocircuit
-- llllllll.co/t/????
--
-- an adaption of
-- mlr v2.2.4 @tehn
-- llllllll.co/t/21145
--
-- for docs go to:
-- github.com/sonocircuits/mlre
-- or smb into code/mlre/docs
--

local g = grid.connect()
local m = midi.connect()

local fileselect = require 'fileselect'
local textentry = require 'textentry'
local pattern_time = require 'pattern_time'

local lfo = include 'lib/hnds_mlre'

local pageNum = 1
local pageLFO = 1
local key1_hold = 0
local scale_idx = 1
local trksel = 0
local dstview = 0
local trsp = 1
local ledview = 1
local quantize = 0
local oneshot_on = 1
local oneshot_rec = false
local transport_run = false
local autolength = false
local loop_pos = 1
local trk_len = 0
local declick = 0.06 -- 60ms delay
local max_cliplength = 42 -- seconds per clip per buffer (max 8 clips in total)

--for transpose scales
local scale_options = {"major", "natural minor", "harmonic minor", "melodic minor", "dorian", "phrygian", "lydian", "mixolydian", "locrian", "custom"}

local trsp_id = {
  {"-oct", "-min7", "-min6", "-perf5", "-perf4", "-min3", "-min2", "none", "maj2", "maj3", "perf4", "perf5", "maj6", "maj7", "oct"}, -- ionian / major
  {"-oct", "-min7", "-maj6", "-perf5", "-perf4", "-maj3", "-maj2", "none", "maj2", "min3", "perf4", "perf5", "min6", "min7", "oct"}, -- aeolian / natural minor
  {"-oct", "-min7", "-maj6", "-perf5", "-perf4", "-maj3", "-min2", "none", "maj2", "min3", "perf4", "perf5", "min6", "maj7", "oct"}, -- hamonic minor
  {"-oct", "-min7", "-maj6", "-perf5", "-perf4", "-min3", "-min2", "none", "maj2", "min3", "perf4", "perf5", "maj6", "maj7", "oct"}, -- melodic minor
  {"-oct", "-min7", "-maj6", "-perf5", "-perf4", "-min3", "-maj2", "none", "maj2", "min3", "perf4", "perf5", "maj6", "min7", "oct"}, -- dorian
  {"-oct", "-maj7", "-maj6", "-perf5", "-perf4", "-maj3", "-maj2", "none", "min2", "min3", "perf4", "perf5", "min6", "min7", "oct"}, -- phrygian
  {"-oct", "-min7", "-min6", "-dim5", "-perf4", "-min3", "-min2", "none", "maj2", "maj3", "dim5", "perf5", "maj6", "maj7", "oct"}, -- lydian
  {"-oct", "-min7", "-min6", "-perf5", "-perf4", "-min3", "-maj2", "none", "maj2", "maj3", "perf4", "perf5", "maj6", "min7", "oct"}, -- mixolydian
  {"-oct", "-maj7", "-maj6", "-perf5", "-dim5", "-maj3", "-maj2", "none", "min2", "min3", "perf4", "dim5", "min6", "min7", "oct"}, -- locrian
  {"-p4+2oct", "-2oct", "-p5+oct", "-p4+oct", "-oct", "-perf5", "-perf4", "none", "perf4", "perf5", "oct", "p4+oct", "p5+oct", "2oct", "p4+2oct"}, -- custom
}

local trsp_scale = {
  {-1200, -1000, -800, -700, -500, -300, -100, 0, 200, 400, 500, 700, 900, 1100, 1200}, -- ionian / major
  {-1200, -1000, -900, -700, -500, -400, -200, 0, 200, 300, 500, 700, 800, 1000, 1200}, -- aeolian / natural minor
  {-1200, -1000, -900, -700, -500, -400, -100, 0, 200, 300, 500, 700, 800, 1100, 1200}, -- hamonic minor
  {-1200, -1000, -900, -700, -500, -300, -100, 0, 200, 300, 500, 700, 900, 1100, 1200}, -- melodic minor
  {-1200, -1000, -900, -700, -500, -300, -200, 0, 200, 300, 500, 700, 900, 1000, 1200}, -- dorian
  {-1200, -1100, -900, -700, -500, -400, -200, 0, 100, 300, 500, 700, 800, 1000, 1200}, -- phrygian
  {-1200, -1000, -800, -600, -500, -300, -100, 0, 200, 400, 600, 700, 900, 1100, 1200}, -- lydian
  {-1200, -1000, -800, -700, -500, -300, -200, 0, 200, 400, 500, 700, 900, 1000, 1200}, -- mixolydian
  {-1200, -1100, -900, -700, -600, -400, -200, 0, 100, 300, 500, 600, 800, 1000, 1200}, -- locrain
  {-3100, -2400, -1900, -1700, -1200, -700, -500, 0, 500, 700, 1200, 1700, 1900, 2400, 3100}, -- custom
}

-- pages and messages
local vREC = 1
local vCUT = 2
local vTRSP = 3
local vLFO = 4
local vCLIP = 15

local view_message = ""

-- events, tempo updates, quantization
local eCUT = 1
local eSTOP = 2
local eSTART = 3
local eLOOP = 4
local eSPEED = 5
local eREV = 6
local eMUTE = 7
local eTRSP = 8
local ePATTERN = 9

local div_options = {"1bar", "1/2", "1/3", "1/4", "1/6", "1/8", "1/16", "1/32"}
local div_values = {1, 2, 3, 4, 6, 8, 16, 32}

local function update_tempo()
  local d = params:get("quant_div")
  div = div_values[d] / 4
  for i = 1, 6 do
    if track[i].tempo_map == 1 then
      clip_resize(i)
    end
  end
end

local prev_tempo = params:get("clock_tempo")
function clock_update_tempo()
  while true do
    clock.sync(1/24)
    local curr_tempo = params:get("clock_tempo")
    if prev_tempo ~= curr_tempo then
      prev_tempo = curr_tempo
      update_tempo()
    end
  end
end

function event_record(e)
  for i = 1, 8 do
    pattern[i]:watch(e)
  end
  recall_watch(e)
end

function event(e)
  if quantize == 1 then
    event_q(e)
  else
    if e.t ~= ePATTERN then
      event_record(e)
    end
    event_exec(e)
  end
end

local quantize_events = {}

function event_q(e)
  table.insert(quantize_events, e)
end

function update_q_clock()
  while true do
    clock.sync(1 / div)
    event_q_clock()
  end
end

function event_q_clock()
  if #quantize_events > 0 then
    for k,e in pairs(quantize_events) do
      if e.t ~= ePATTERN then event_record(e) end
      event_exec(e)
    end
    quantize_events = {}
  end
end

-- exec function
function event_exec(e)
  if e.t == eCUT then
    if track[e.i].loop == 1 then
      track[e.i].loop = 0
      softcut.loop_start(e.i, clip[track[e.i].clip].s)
      softcut.loop_end(e.i, clip[track[e.i].clip].e)
    end
    local cut = (e.pos / 16) * clip[track[e.i].clip].l + clip[track[e.i].clip].s
    softcut.position(e.i, cut)
    if track[e.i].play == 0 then
      track[e.i].play = 1
      softcut.play(e.i, 1)
      softcut.rec(e.i, 1)
      clock.run(
      function()
        clock.sleep(declick)
        if track[e.i].mute == 0 then
          softcut.level(e.i, track[e.i].level)
        end
      end)
    end
    dirtygrid = true
  elseif e.t == eSTOP then
    softcut.level(e.i, 0)
    clock.run(
    function()
      clock.sleep(declick)
      track[e.i].play = 0
      softcut.play(e.i, 0)
      softcut.rec(e.i, 0)
      dirtygrid = true
    end)
  elseif e.t == eSTART then
    track[e.i].play = 1
    softcut.play(e.i, 1)
    softcut.rec(e.i, 1)
    clock.run(
    function()
      clock.sleep(declick)
      if track[e.i].mute == 0 then
        softcut.level(e.i, track[e.i].level)
      end
      dirtygrid = true
    end)
  elseif e.t == eLOOP then
    track[e.i].loop = 1
    track[e.i].loop_start = e.loop_start
    track[e.i].loop_end = e.loop_end
    local lstart = clip[track[e.i].clip].s + (track[e.i].loop_start - 1) / 16 * clip[track[e.i].clip].l
    local lend = clip[track[e.i].clip].s + (track[e.i].loop_end) / 16 * clip[track[e.i].clip].l
    softcut.loop_start(e.i, lstart)
    softcut.loop_end(e.i, lend)
    if view == vREC then dirtygrid = true end
    if view == vCUT then dirtygrid = true end
    if view == vTRSP then dirtygrid = true end
  elseif e.t == eSPEED then
    track[e.i].speed = e.speed
    update_rate(e.i)
    if view == vREC then dirtygrid = true end
  elseif e.t == eREV then
    track[e.i].rev = e.rev
    update_rate(e.i)
    dirtygrid = true
  elseif e.t == eMUTE then
    track[e.i].mute = e.mute
    set_level(e.i)
  elseif e.t == eTRSP then
    track[e.i].trsp = e.trsp
    params:set(e.i.."transpose", track[e.i].trsp)
    if view == vTRSP then dirtygrid = true end
    if view == vCUT then dirtygrid = true end
  elseif e.t == eBUFF then
    track[e.i].buffer = e.buffer
    params:set(e.i.."buffer_sel", track[e.i].buffer)
    if view == vREC then dirtygrid = true end
  elseif e.t == ePATTERN then
    if e.action == "stop" then pattern[e.i]:stop()
    elseif e.action == "start" then pattern[e.i]:start()
    elseif e.action == "rec_stop" then pattern[e.i]:rec_stop()
    elseif e.action == "rec_start" then pattern[e.i]:rec_start()
    elseif e.action == "clear" then pattern[e.i]:clear()
    elseif e.action == "overdub_on" then pattern[e.i]:set_overdub(1)
    elseif e.action == "overdub_off" then pattern[e.i]:set_overdub(0)
    end
  end
end

local patterns_only = false
pattern = {}
for i = 1, 8 do
  pattern[i] = pattern_time.new()
  pattern[i].process = event_exec
end

recall = {}
for i = 1, 4 do
  recall[i] = {}
  recall[i].recording = false
  recall[i].has_data = false
  recall[i].active = false
  recall[i].event = {}
end

function recall_watch(e)
  for i = 1, 4 do
    if recall[i].recording == true then
      table.insert(recall[i].event, e)
      recall[i].has_data = true
    end
  end
end

function recall_exec(i)
  for _,e in pairs(recall[i].event) do
    event_exec(e)
  end
end

-- for tracks and clip settings
track = {}
for i = 1, 6 do
  track[i] = {}
  track[i].head = (i - 1) % 4 + 1
  track[i].play = 0
  track[i].sel = 0
  track[i].rec = 0
  track[i].oneshot = 0
  track[i].level = 1
  track[i].mute = 0
  track[i].rec_level = 1
  track[i].pre_level = 0
  track[i].dry_level = 0
  track[i].send_t5 = 1
  track[i].send_t6 = 1
  track[i].loop = 0
  track[i].loop_start = 0
  track[i].loop_end = 16
  track[i].dur = 4
  track[i].clip = i
  track[i].pos = 0
  track[i].pos_grid = -1
  track[i].speed = 0
  track[i].warble = 0
  track[i].rev = 0
  track[i].tempo_map = 0
  track[i].trsp = 8
  track[i].transpose = 0
  track[i].fade = 0
  track[i].buffer = 0
  track[i].side = 0
end

set_clip_length = function(i, len, r_val)
  clip[i].l = len
  clip[i].e = clip[i].s + len
  clip[i].bpm = 60 / len * r_val
end

clip = {}
for i = 1, 8 do
  clip[i] = {}
  clip[i].s = 2 + (i - 1) * max_cliplength
  clip[i].name = "-"
  clip[i].info = "length: 4.00s"
  clip[i].reset = 4
  set_clip_length(i, 4, 4)
end

set_clip = function(i, x)
  track[i].clip = x
  softcut.loop_start(i, clip[track[i].clip].s)
  softcut.loop_end(i, clip[track[i].clip].e)
  local q = calc_quant(i)
  local off = calc_quant_off(i, q)
  softcut.phase_quant(i, q)
  softcut.phase_offset(i, off)
end

calc_quant = function(i)
  local q = (clip[track[i].clip].l / 16)
  return q
end

calc_quant_off = function(i, q)
  local off = q
  while off < clip[track[i].clip].s do
    off = off + q
  end
  off = off - clip[track[i].clip].s
  return off
end

function clear_clip(i) -- clear active buffer of clip and set clip length
  local buffer = params:get(i.."buffer_sel")
  local tempo = params:get("clock_tempo")
  local r_idx = params:get(track[i].clip.."clip_length")
  local r_val = resize_values[r_idx]
  local resize
  if track[i].tempo_map == 1 and params:get("t_map_mode") == 1 then
    resize = (60 / tempo) * r_val
  elseif track[i].tempo_map == 1 and params:get("t_map_mode") == 2 then
    resize = clip[track[i].clip].l
  else
    resize = r_val
  end
  softcut.buffer_clear_region_channel(buffer, clip[track[i].clip].s, clip[track[i].clip].s + max_cliplength)
  set_clip_length(track[i].clip, resize, r_val)
  set_clip(i, track[i].clip)
  update_rate(i)
  clip[track[i].clip].reset = resize
  clip[track[i].clip].name = "-"
  clip[track[i].clip].info = "length: "..string.format("%.2f", resize).."s"
end

function clip_reset(i) -- reset clip to default length
  local resize = clip[track[i].clip].reset
  set_clip_length(track[i].clip, resize, 4) -- resize to "reset" length
  set_clip(i, track[i].clip)
  update_rate(i)
  clip[track[i].clip].info = "length: "..string.format("%.2f", resize).."s"
end

function clip_resize(i) -- resize clip length oder track speed according to t_map settings
  local tempo = params:get("clock_tempo")
  local r_idx = params:get(track[i].clip.."clip_length")
  local r_val = resize_values[r_idx]
  local resize
  if track[i].tempo_map == 1 and params:get("t_map_mode") == 1 then
    resize = (60 / tempo) * r_val
  elseif track[i].tempo_map == 1 and params:get("t_map_mode") == 2 then
    resize = clip[track[i].clip].l
  else
    resize = r_val
  end
  if resize > max_cliplength then
    resize = max_cliplength
  end
  set_clip_length(track[i].clip, resize, r_val)
  set_clip(i, track[i].clip)
  update_rate(i)
  if track[i].tempo_map == 1 and params:get("t_map_mode") == 2 then
    clip[track[i].clip].info = "repitch factor: "..string.format("%.2f", tempo / clip[track[i].clip].bpm)
  else
    clip[track[i].clip].info = "length: "..string.format("%.2f", resize).."s"
  end
end

-- softcut functions
function set_rec(n) -- set softcut rec and pre levels
  if track[n].fade == 0 then
    if track[n].rec == 1 then
      softcut.pre_level(n, track[n].pre_level)
      softcut.rec_level(n, track[n].rec_level)
    else
      softcut.pre_level(n, 1)
      softcut.rec_level(n, 0)
    end
  elseif track[n].fade == 1 then
    if track[n].rec == 1 then
      softcut.pre_level(n, track[n].pre_level)
      softcut.rec_level(n, track[n].rec_level)
    else
      softcut.pre_level(n, track[n].pre_level)
      softcut.rec_level(n, 0)
    end
  end
  if view ~= vLFO and pageNum == 1 then dirtyscreen = true end
end

function rec_enable(i)
  track[i].rec = 1 - track[i].rec
  set_rec(i)
  chop(i)
  if view == vREC then dirtygrid = true end
end

function set_level(n) -- set track volume and mute track
  if track[n].mute == 1 then
    softcut.level(n, 0)
  elseif track[n].mute == 0 then
    softcut.level(n, track[n].level)
  end
  if view ~= vLFO and pageNum == 1 then dirtyscreen = true end
end

function set_buffer(n) -- select softcut buffer to record to
  if track[n].side == 1 then
    softcut.buffer(n, 2)
  else
    softcut.buffer(n, 1)
  end
  if view == vREC then dirtygrid = true end
end

function copy_buffer(i)
  local src_ch
  local dst_ch
  local src_name = ""
  local dst_name = ""
  if params:get(i.."buffer_sel") == 1 then
    src_ch = 1
    dst_ch = 2
    src_name = "main"
    dst_name = "temp"
  else
    src_ch = 2
    dst_ch = 1
    src_name = "temp"
    dst_name = "main"
  end
  softcut.buffer_copy_mono(src_ch, dst_ch, clip[track[i].clip].s, clip[track[i].clip].s, max_cliplength)
  show_message("clip "..track[i].clip.." copied to "..dst_name.." buffer")
end

-- for track routing
route = {}
route.adc = 1
route.tape = 0
for i = 1, 6 do
  route[i] = {}
  route[i].t5 = 0
  route[i].t6 = 0
end

function set_track_route(n) -- internal softcut routing
  if route[n].t5 == 1 then
    softcut.level_cut_cut(n, 5, track[n].send_t5)
  else
    softcut.level_cut_cut(n, 5, 0)
  end
  if route[n].t6 == 1 then
    softcut.level_cut_cut(n, 6, track[n].send_t6)
  else
    softcut.level_cut_cut(n, 6, 0)
  end
end

function set_track_source() -- select audio source
  if route.adc == 1 then
    audio.level_adc_cut(1)
  else
    audio.level_adc_cut(0)
  end
  if route.tape == 1 then
    audio.level_tape_cut(1)
  else
    audio.level_tape_cut(0)
  end
end

function update_softcut_input(n) -- select softcut input
  if params:get(n.."input_options") == 1 then -- L&R
    softcut.level_input_cut(1, n, 0.5)
    softcut.level_input_cut(2, n, 0.5)
  elseif params:get(n.."input_options") == 2 then -- L IN
    softcut.level_input_cut(1, n, 1)
    softcut.level_input_cut(2, n, 0)
 elseif params:get(n.."input_options") == 3 then -- R IN
    softcut.level_input_cut(1, n, 0)
    softcut.level_input_cut(2, n, 1)
 elseif params:get(n.."input_options") == 4 then -- OFF
    softcut.level_input_cut(1, n, 0)
    softcut.level_input_cut(2, n, 0)
  end
end

function filter_select(n) -- select filter type
  if params:get(n.."filter_type") == 1 then -- lpf
    softcut.post_filter_lp(n, 1)
    softcut.post_filter_hp(n, 0)
    softcut.post_filter_bp(n, 0)
    softcut.post_filter_br(n, 0)
    softcut.post_filter_dry(n, track[n].dry_level)
  elseif params:get(n.."filter_type") == 2 then -- hpf
    softcut.post_filter_lp(n, 0)
    softcut.post_filter_hp(n, 1)
    softcut.post_filter_bp(n, 0)
    softcut.post_filter_br(n, 0)
    softcut.post_filter_dry(n, track[n].dry_level)
  elseif params:get(n.."filter_type") == 3 then -- bpf
    softcut.post_filter_lp(n, 0)
    softcut.post_filter_hp(n, 0)
    softcut.post_filter_bp(n, 1)
    softcut.post_filter_br(n, 0)
    softcut.post_filter_dry(n, track[n].dry_level)
  elseif params:get(n.."filter_type") == 4 then -- brf
    softcut.post_filter_lp(n, 0)
    softcut.post_filter_hp(n, 0)
    softcut.post_filter_bp(n, 0)
    softcut.post_filter_br(n, 1)
    softcut.post_filter_dry(n, track[n].dry_level)
  elseif params:get(n.."filter_type") == 5 then -- off
    softcut.post_filter_lp(n, 0)
    softcut.post_filter_hp(n, 0)
    softcut.post_filter_bp(n, 0)
    softcut.post_filter_br(n, 0)
    softcut.post_filter_dry(n, 1)
  end
  if view ~= vLFO and pageNum == 2 then dirtyscreen = true end
end

-- for lfos (hnds_mlre)
local lfo_targets = {"none"}
for i = 1, 6 do
  table.insert(lfo_targets, i.."vol")
  table.insert(lfo_targets, i.."pan")
  table.insert(lfo_targets, i.."dub")
  table.insert(lfo_targets, i.."transpose")
  table.insert(lfo_targets, i.."rate_slew")
  table.insert(lfo_targets, i.."cutoff")
end

function lfo.process()
  for i = 1, 6 do
    local target = params:get(i.."lfo_target")
    local target_name = string.sub(lfo_targets[target], 2)
    local voice = string.sub(lfo_targets[target], 1, 1)
    if params:get(i.."lfo") == 2 then
      if target_name == "vol" then
        params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1.0, 1.0, 0, 1.0))
      elseif target_name == "pan" then
        params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1.0, 1.0, -1.0, 1.0))
      elseif target_name == "dub" then
        params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1.0, 1.0, 0, 1.0))
      elseif target_name == "transpose" then
        params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1.0, 1.0, 1, 16))
      elseif target_name == "rate_slew" then
        params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1.0, 1.0, 0, 1.0))
      elseif target_name == "cutoff" then
        params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1.0, 1.0, 20, 18000))
      end
    end
  end
  if view == 4 then dirtygrid = true end -- for blinkenlights (lfo slope on "on" grid key)
end

-- tape warble
local warble = {}
for i = 1, 6 do
  warble[i] = {}
  warble[i].freq = 8
  warble[i].counter = 1
  warble[i].slope = 0
  warble[i].active = false
end

function make_warble() -- warbletimer function
  local tau = math.pi * 2
  for i = 1, 6 do
    -- make sine (from hnds)
    local slope = 1 * math.sin(((tau / 100) * (warble[i].counter)) - (tau / (warble[i].freq)))
    warble[i].slope = util.linlin(-1, 1, -1, 0, math.max(-1, math.min(1, slope))) * (params:get(i.."warble_depth") * 0.001)
    warble[i].counter = warble[i].counter + warble[i].freq
    -- activate warble
    if track[i].warble == 1 and track[i].play == 1 and math.random(100) <= params:get(i.."warble_amount") then
      if not warble[i].active then
        warble[i].active = true
      end
    end
    -- make warble
    if warble[i].active then
      local n = math.pow(2, track[i].speed + track[i].transpose + params:get(i.."detune"))
      if track[i].rev == 1 then n = -n end
      if track[i].tempo_map == 1 and params:get("t_map_mode") == 2 then
        local bpmmod = params:get("clock_tempo") / clip[track[i].clip].bpm
        n = n * bpmmod
      end
      local warble_rate = n * (1 + warble[i].slope)
      softcut.rate(i, warble_rate)
    end
    -- stop warble
    if warble[i].active and warble[i].slope > -0.001 then -- nearest value to zero
      warble[i].active = false
      update_rate(i) -- reset rate
    end
  end
end

-- scale and transpose functions
function set_scale(n) -- set scale id, thanks zebra
  for i = 1, 6 do
    local p = params:lookup_param(i.."transpose")
    p.options = trsp_id[n]
    p:bang()
  end
  if view ~= vLFO and pageNum == 3 then dirtyscreen = true end
end

function set_transpose(i, x) -- transpose track
  local scale_idx = params:get("scale")
  track[i].transpose = trsp_scale[scale_idx][x] / 1200
  update_rate(i)
  if view ~= vLFO and pageNum == 3 then dirtyscreen = true end
end

-- transport functions
function toggle_playback(i)
  if track[i].play == 1 then
    e = {}
    e.t = eSTOP
    e.i = i
    event(e)
  else
    e = {}
    e.t = eSTART
    e.i = i
    event(e)
    if params:get("midi_trnsp") == 2 and transport_run == false then
      m:start()
      transport_run = true
    end
  end
end

function stopall() -- stop all tracks and send midi stop if set in params
  for i = 1, 6 do
    e = {} e.t = eSTOP e.i = i
    event(e)
  end
  for i = 1, 8 do
    pattern[i]:stop()
  end
  if params:get("midi_trnsp") == 2 then
    m:stop()
    transport_run = false
  end
end

function altrun() -- alt run function for selected tracks
  for i = 1, 6 do
    if track[i].sel == 1 then
      if track[i].play == 1 then
        e = {} e.t = eSTOP e.i = i
      elseif track[i].play == 0 then
        e = {} e.t = eSTART e.i = i
      end
      event(e)
    end
  end
end

function retrig() -- retrig function for playing tracks
  for i = 1, 6 do
    if track[i].play == 1 then
      if track[i].rev == 0 then
        e = {} e.t = eCUT e.i = i e.pos = 0
      elseif track[i].rev == 1 then
        e = {} e.t = eCUT e.i = i e.pos = 15
      end
    end
    event(e)
  end
end

-- threshold recording
function arm_thresh_rec(i) -- start poll if oneshot == 1
  if track[i].oneshot == 1 then
    amp_in[1]:start()
    amp_in[2]:start()
  else
    amp_in[1]:stop()
    amp_in[2]:stop()
  end
  if track[i].play == 0 then
    if track[i].rev == 1 then
      loop_pos = 16
      track[i].pos_grid = 15
    else
      loop_pos = 1
      track[i].pos_grid = 0
    end
  end
end

function thresh_rec() -- start rec when threshold is reached
  local i = oneshot_on
  if track[i].oneshot == 1 then
    track[i].rec = 1
    set_rec(i)
    trk_len = 0
    if track[i].play == 0 then
      if track[i].rev == 0 then
        e = {} e.t = eCUT e.i = i e.pos = 0
      elseif track[i].rev == 1 then
        e = {} e.t = eCUT e.i = i e.pos = 15
      end
      event(e)
    end
  end
end

function update_cycle(n) -- calculate cycle length when oneshot == 1
  local tempo = params:get("clock_tempo")
  oneshot_rec = false
  if track[n].oneshot == 1 then
    if track[n].tempo_map == 1 and params:get("t_map_mode") == 2 then
      track[n].dur = ((60 / tempo) * clip[track[n].clip].l) / math.pow(2, track[n].speed + track[n].transpose + params:get(n.."detune"))
    else
      track[n].dur = clip[track[n].clip].l / math.pow(2, track[n].speed + track[n].transpose + params:get(n.."detune"))
    end
    if track[n].loop == 1 and track[n].play == 1 then
      local len = track[n].loop_end - track[n].loop_start + 1
      track[n].dur = (track[n].dur / 16) * len
    end
  end
end

function oneshot(cycle) -- called by clock coroutine at threshold
  clock.sleep(cycle) -- length of cycle for time interval specified by 'track[i].dur'
  if track[oneshot_on].oneshot == 1 then
    track[oneshot_on].rec = 0
    track[oneshot_on].oneshot = 0
  end
  set_rec(oneshot_on)
  if track[oneshot_on].sel == 1 and params:get("auto_rand") == 2 and oneshot_rec == true then --randomize selected tracks
    randomize(oneshot_on)
  end
  tracktimer:stop()
end

function count_length()
  trk_len = trk_len + 1
end

function loop_point() -- set loop start point (loop_pos) for chop function
  if track[oneshot_on].oneshot == 1 then
    if track[oneshot_on].rev == 1 then
      if track[oneshot_on].pos_grid == 15 then
        loop_pos = 16
      else
        loop_pos = track[oneshot_on].pos_grid + 1
      end
    else
      if track[oneshot_on].pos_grid == 0 then
        loop_pos = 1
      else
        loop_pos = track[oneshot_on].pos_grid + 1
      end
    end
  end
end

function chop(i) -- called when rec is toggled
  if oneshot_rec == true and track[i].oneshot == 1 then
    if not autolength then -- set loop mode
      e = {}
      e.t = eLOOP
      e.i = i
      e.loop = 1
      e.loop_start = math.min(loop_pos, track[i].pos_grid + 1)
      e.loop_end = math.max(loop_pos, track[i].pos_grid + 1)
      event(e)
      track[i].oneshot = 0
    else -- autolength mode
      local l = trk_len / 100
      tracktimer:stop()
      set_clip_length(track[i].clip, l, 1) -- check diff r_val values
      set_clip(i, track[i].clip)
      update_rate(i)
      track[i].oneshot = 0
      autolength = false
      clip[track[i].clip].reset = l
      clip[track[i].clip].info = "length: "..string.format("%.2f", l).."s"
    end
    if track[i].sel == 1 and params:get("auto_rand") == 2 then --randomize selected tracks
      randomize(i)
    end
    oneshot_rec = false
  end
end

function randomize(i) -- randomize parameters
  if params:get("rnd_transpose") == 2 then
    params:set(i.."transpose", math.random(1, 15))
  end
  if params:get("rnd_vol") == 2 then
    params:set(i.."vol", math.random(20, 100) / 100)
  end
  if params:get("rnd_pan") == 2 then
    params:set(i.."pan", (math.random() * 20 - 10) / 10)
  end
  if params:get("rnd_dir") == 2 then
    e = {} e.t = eREV e.i = i e.rev = math.random(0, 1)
    event(e)
  end
  if params:get("rnd_loop") == 2 then
    e = {}
    e.t = eLOOP
    e.i = i
    e.loop = 1
    e.loop_start = math.random(1, 15)
    e.loop_end = math.random(e.loop_start, 16)
    event(e)
  end
  if params:get("rnd_speed") == 2 then
    e = {} e.t = eSPEED e.i = i e.speed = math.random(- params:get("rnd_loct"), params:get("rnd_uoct"))
    event(e)
  end
  if params:get("rnd_cut") == 2 then
    params:set(i.. "cutoff", math.random(params:get("rnd_lcut"), params:get("rnd_ucut")) )
  end
end

-- interface
view = vREC
view_prev = view

v = {}
v.key = {}
v.enc = {}
v.redraw = {}
v.gridkey = {}
v.gridredraw = {}

viewinfo = {}
viewinfo[vREC] = 0
viewinfo[vLFO] = 0

focus = 1
alt = 0
alt2 = 0

held = {}
heldmax = {}
done = {}
first = {}
second = {}
for i = 1, 8 do
  held[i] = 0
  heldmax[i] = 0
  done[i] = 0
  first[i] = 0
  second[i] = 0
end

function key(n, z)
  if n == 1 then
    key1_hold = z
    dirtyscreen = true
  else
    _key(n, z)
  end
end

function enc(n, d) _enc(n, d) end

function redraw() _redraw() end

function screenredraw()
  if dirtyscreen then
    redraw()
    dirtyscreen = false
  end
end

function g.key(x, y, z) _gridkey(x, y, z) end

function gridredraw()
  if not g then return end
  if dirtygrid == true then
    _gridredraw()
    dirtygrid = false
  end
end

set_view = function(x)
  if x == -1 then x = view_prev end
  view_prev = view
  view = x
  _key = v.key[x]
  _enc = v.enc[x]
  _redraw = v.redraw[x]
  _gridkey = v.gridkey[x]
  _gridredraw = v.gridredraw[x]
  dirtyscreen = true
  dirtygrid = true
end

function ledpulse()
  ledview = (ledview % 8) + 4
  for i = 1, 8 do
    if pattern[i].overdub == 1 then
      dirtygrid = true
    end
  end
  for i = 1, 6 do
    if track[i].oneshot == 1 then
      dirtygrid = true
    end
  end
end

function show_message(message)
  clock.run(function()
    view_message = message
    dirtyscreen = true
    if string.len(message) > 20 then
      clock.sleep(1.6) -- long display time
      view_message = ""
      dirtyscreen = true
    else
      clock.sleep(0.8) -- short display time
      view_message = ""
      dirtyscreen = true
    end
  end)
end

-- midi
function build_midi_device_list()
  midi_devices = {}
  for i = 1, #midi.vports do
    local long_name = midi.vports[i].name
    local short_name = string.len(long_name) > 15 and util.acronym(long_name) or long_name
    table.insert(midi_devices, i..": "..short_name)
  end
end

function midi.add() -- MIDI register callback
  build_midi_device_list()
end

function midi.remove() -- MIDI remove callback
  clock.run(
    function()
      clock.sleep(0.2)
      build_midi_device_list()
    end
  )
end

-- init
init = function()

-- params for "globals"
  params:add_separator("global")

  -- params for scales
  params:add_option("scale", "scale", scale_options, 1)
  params:set_action("scale", function(n) set_scale(n) end)

  -- params for rec threshold
  params:add_control("rec_threshold", "rec threshold", controlspec.new(-40, 6, 'lin', 0.01, -12, "dB"))
  -- not as much fine control with db but it's more intuitive to me (increment of 0.01 doesn't work when neg values involved)

  -- tempo map behaviour
  params:add_option("t_map_mode", "tempo-map mode", {"resize", "repitch"}, 1)

  -- event recording slots
  params:add_option("event_slots", "event slots", {"default", "pattern only"}, 1)
  params:set_action("event_slots", function(x) patterns_only = x == 2 and true or false dirtygrid = true end)

  -- midi params
  params:add_group("midi settings", 2)
  -- midi device
  build_midi_device_list()
  params:add_option("global_midi_device", "midi device", midi_devices, 1)
  params:set_action("global_midi_device", function(val) m = midi.connect(val) end)
  -- send midi transport
  params:add_option("midi_trnsp","MIDI transport", {"off", "send"}, 1)

  -- global track control
  params:add_group("track control", 6)
  params:add_separator("control focused track")
  -- playback
  params:add_binary("track_focus_playback", "playback", "momentary", 0)
  params:set_action("track_focus_playback", function(v) if v == 1 then toggle_playback(focus) end end)
  -- record enable
  params:add_binary("rec_focus_enable", "record", "momentary", 0)
  params:set_action("rec_focus_enable", function(v) if v == 1 then rec_enable(focus) end end)
  -- reverse
  params:add_binary("tog_focus_rev", "reverse", "momentary", 0)
  params:set_action("tog_focus_rev", function(v) if v == 1 then local i = focus local n = 1 - track[i].rev e = {} e.t = eREV e.i = i e.rev = n event(e) end end)
  -- speed +
  params:add_binary("inc_focus_speed", "speed +", "momentary", 0)
  params:set_action("inc_focus_speed", function(v) if v == 1 then local i = focus local n = util.clamp(track[i].speed + 1, -3, 3) e = {} e.t = eSPEED e.i = i e.speed = n event(e) end end)
  -- speed -
  params:add_binary("dec_focus_speed", "speed -", "momentary", 0)
  params:set_action("dec_focus_speed", function(v) if v == 1 then local i = focus local n = util.clamp(track[i].speed - 1, -3, 3) e = {} e.t = eSPEED e.i = i e.speed = n event(e) end end)

  -- randomize settings
  params:add_group("randomize settings", 15)
  params:add_option("auto_rand","auto-randomize", {"off", "on"}, 1)

  params:add_separator("")
  params:add_option("rnd_transpose", "transpose", {"off", "on"}, 1)
  params:add_option("rnd_vol", "volume", {"off", "on"}, 1)
  params:add_option("rnd_pan", "pan", {"off", "on"}, 1)
  params:add_option("rnd_dir", "direction", {"off", "on"}, 2)
  params:add_option("rnd_loop", "loop", {"off", "on"}, 2)

  params:add_separator("")
  params:add_option("rnd_speed", "speed", {"off", "on"}, 2)
  params:add_number("rnd_uoct", "+ oct range", 0, 3, 2)
  params:add_number("rnd_loct", "- oct range", 0, 3, 2)

  params:add_separator("")
  params:add_option("rnd_cut", "cutoff", {"off", "on"}, 1)
  params:add_control("rnd_ucut", "upper freq", controlspec.new(20, 18000, 'exp', 1, 18000, "Hz"))
  params:add_control("rnd_lcut", "lower freq", controlspec.new(20, 18000, 'exp', 1, 20, "Hz"))

  -- params for tracks
  params:add_separator("tracks")

  audio.level_cut(1)
  audio.level_tape(1)

  for i = 1, 6 do
    params:add_group("track "..i, 27)

    params:add_separator("tape")
    -- select buffer
    params:add_option(i.."buffer_sel", i.." buffer", {"main", "temp"}, 1)
    params:set_action(i.."buffer_sel", function(x) track[i].side = x - 1 set_buffer(i) end)
    -- track volume
    params:add_control(i.."vol", i.." vol", controlspec.new(0, 1, 'lin', 0, 1, ""))
    params:set_action(i.."vol", function(x) track[i].level = x set_level(i) end)
    -- track pan
    params:add_control(i.."pan", i.." pan", controlspec.new(-1, 1, 'lin', 0, 0, ""))
    params:set_action(i.."pan", function(x) softcut.pan(i, x) if view ~= vLFO and pageNum == 1 then dirtyscreen = true end end)
    -- record level
    params:add_control(i.."rec", i.." rec", controlspec.new(0, 1, 'lin', 0, 1, ""))
    params:set_action(i.."rec", function(x) track[i].rec_level = x set_rec(i) end)
    -- overdub level
    params:add_control(i.."dub", i.." dub", controlspec.UNIPOLAR)
    params:set_action(i.."dub", function(x) track[i].pre_level = x set_rec(i) end)
    -- detune
    params:add_control(i.."detune", i.." detune", controlspec.BIPOLAR)
    params:set_action(i.."detune", function() update_rate(i) if view ~= vLFO and pageNum == 3 then dirtyscreen = true end end)
    -- transpose
    params:add_option(i.."transpose", i.." transpose", trsp_id[params:get("scale")], 8)
    params:set_action(i.."transpose", function(x) set_transpose(i, x) end)
    -- rate slew
    params:add_control(i.."rate_slew", i.." rate slew", controlspec.new(0, 1, 'lin', 0, 0, ""))
    params:set_action(i.."rate_slew", function(x) softcut.rate_slew_time(i, x) if view ~= vLFO and pageNum == 3 then dirtyscreen = true end end)
    -- level slew
    params:add_control(i.."level_slew", i.." level slew", controlspec.new(0.1, 10.0, "lin", 0.1, 0.1, ""))
    params:set_action(i.."level_slew", function(x) softcut.level_slew_time(i, x) if view ~= vLFO and pageNum == 3 then dirtyscreen = true end end)
    -- send level track 5
    params:add_control(i.."send_track5", i.." send track 5", controlspec.new(0, 1, 'lin', 0, 1, ""))
    params:set_action(i.."send_track5", function(x) track[i].send_t5 = x set_track_route(i) end)
    params:hide(i.."send_track5")
    -- send level track 6
    params:add_control(i.."send_track6", i.." send track 6", controlspec.new(0, 1, 'lin', 0, 1, ""))
    params:set_action(i.."send_track6", function(x) track[i].send_t6 = x set_track_route(i) end)
    params:hide(i.."send_track6")

    -- filter params
    params:add_separator("filter")
    -- cutoff
    params:add_control(i.."cutoff", i.." cutoff", controlspec.new(20, 18000, 'exp', 1, 18000, "Hz"))
    params:set_action(i.."cutoff", function(x) softcut.post_filter_fc(i, x) if view ~= vLFO and pageNum == 2 then dirtyscreen = true end end)
    -- filter q
    params:add_control(i.."filter_q", i.." filter q", controlspec.new(0.1, 4.0, 'exp', 0.01, 2.0, ""))
    params:set_action(i.."filter_q", function(x) softcut.post_filter_rq(i, x) if view ~= vLFO and pageNum == 2 then dirtyscreen = true end end)
    -- filter type
    params:add_option(i.."filter_type", i.." type", {"low pass", "high pass", "band pass", "band reject", "off"}, 1)
    params:set_action(i.."filter_type", function() filter_select(i) end)
    -- post filter dry level
    params:add_control(i.."post_dry", i.." dry level", controlspec.new(0, 1, 'lin', 0, 0, ""))
    params:set_action(i.."post_dry", function(x) track[i].dry_level = x softcut.post_filter_dry(i, x) if view ~= vLFO and pageNum == 2 then dirtyscreen = true end end)

    -- warble params
    params:add_separator("wow & flutter")
    -- warble amount
    params:add_number(i.."warble_amount", i.." amount", 0, 100, 10, function(param) return (param:get().." %") end)
    -- warble depth
    params:add_number(i.."warble_depth", i.." depth", 0, 100, 12, function(param) return (param:get().." %") end)
    -- warble freq
    params:add_control(i.."warble_freq",i.." speed", controlspec.new(1.0, 10.0, "lin", 0.1, 6.0, ""))
    params:set_action(i.."warble_freq", function(val) warble[i].freq = val * 2 end)

    -- track control
    params:add_separator("track control")
    -- playback
    params:add_binary(i.."track_playback", i.." playback", "momentary", 0)
    params:set_action(i.."track_playback", function(v) if v == 1 then toggle_playback(i) end end)
    -- record enable
    params:add_binary(i.."rec_enable", i.." record", "momentary", 0)
    params:set_action(i.."rec_enable", function(v) if v == 1 then rec_enable(i) end end)
    -- reverse
    params:add_binary(i.."tog_rev", i.." reverse", "momentary", 0)
    params:set_action(i.."tog_rev", function(v) if v == 1 then local n = 1 - track[i].rev e = {} e.t = eREV e.i = i e.rev = n event(e) end end)
    -- speed +
    params:add_binary(i.."inc_speed", i.." speed +", "momentary", 0)
    params:set_action(i.."inc_speed", function(v) if v == 1 then local n = util.clamp(track[i].speed + 1, -3, 3) e = {} e.t = eSPEED e.i = i e.speed = n event(e) end end)
    -- speed -
    params:add_binary(i.."dec_speed", i.." speed -", "momentary", 0)
    params:set_action(i.."dec_speed", function(n) if n == 1 then local n = util.clamp(track[i].speed - 1, -3, 3) e = {} e.t = eSPEED e.i = i e.speed = n event(e) end end)

    -- input options
    params:add_option(i.."input_options", i.." input options", {"L+R", "L IN", "R IN", "OFF"}, 1)
    params:set_action(i.."input_options", function() update_softcut_input(i) end)
    params:hide(i.."input_options")

    -- softcut settings
    softcut.enable(i, 1)
    softcut.buffer(i, 1)

    softcut.play(i, 0)
    softcut.rec(i, 0)

    softcut.level(i, 1)
    softcut.pan(i, 0)

    softcut.pre_level(i, 1)
    softcut.rec_level(i, 0)

    softcut.fade_time(i, 0.01)
    softcut.level_slew_time(i, 0.1)
    softcut.rate_slew_time(i, 0)

    softcut.loop_start(i, clip[track[i].clip].s)
    softcut.loop_end(i, clip[track[i].clip].e)
    softcut.loop(i, 1)
    softcut.position(i, clip[track[i].clip].s)

    update_rate(i)
    set_clip(i, i)

  end

  -- params for modulation (hnds_mlre)
  params:add_separator("modulation")
  for i = 1, 6 do lfo[i].lfo_targets = lfo_targets end
  lfo.init()

  -- params for clip resize
  for i = 1, 8 do
    params:add_option(i.."clip_length", i.." clip length", resize_options, 4)
    params:hide(i.."clip_length")
  end

  -- params for quant division
  params:add_option("quant_div", "quant div", div_options, 7)
  params:set_action("quant_div", function() update_tempo() end)
  params:hide("quant_div")

  -- params for clock tempo
  params:set_action("clock_tempo", function() update_tempo() end)

  -- pset callback
  params.action_write = function(filename, name)
    -- get pset number
    local pset_string = string.sub(filename, string.len(filename) - 6, -1)
    local number = pset_string:gsub(".pset", "")

    -- make directory
    os.execute("mkdir -p "..norns.state.data.."sessions/"..number.."/")

    -- save buffer content
    softcut.buffer_write_mono(norns.state.data.."sessions/"..number.."/"..name.."_buffer.wav", 0, -1, 1)

    -- save data in one big table
    local sesh_data = {}
    -- clip data
    for i = 1, 8 do
      sesh_data[i] = {}
      sesh_data[i].clip_name = clip[i].name
      sesh_data[i].clip_info = clip[i].info
      sesh_data[i].clip_reset = clip[i].reset
      sesh_data[i].clip_e = clip[i].e
      sesh_data[i].clip_l = clip[i].l
      sesh_data[i].clip_bpm = clip[i].bpm
    end
    -- route data
    for i = 1, 5 do
      sesh_data[i].route_t5 = route[i].t5
      sesh_data[i].route_t6 = route[i].t6
    end
    -- track data
    for i = 1, 6 do
      sesh_data[i].track_sel = track[i].sel
      sesh_data[i].track_fade = track[i].fade
      sesh_data[i].track_mute = track[i].mute
      sesh_data[i].track_speed = track[i].speed
      sesh_data[i].track_rev = track[i].rev
      sesh_data[i].track_warble = track[i].warble
      sesh_data[i].track_tempo_map = track[i].tempo_map
      sesh_data[i].track_loop = track[i].loop
      sesh_data[i].track_loop_start = track[i].loop_start
      sesh_data[i].track_loop_end = track[i].loop_end
      sesh_data[i].track_clip = track[i].clip
    end
    -- pattern data
    for i = 1, 8 do
      sesh_data[i].pattern_count = pattern[i].count
      sesh_data[i].pattern_time = pattern[i].time
      sesh_data[i].pattern_event = pattern[i].event
      sesh_data[i].pattern_time_factor = pattern[i].time_factor
    end
    -- recall data
    for i = 1, 4 do
      sesh_data[i].recall_has_data = recall[i].has_data
      sesh_data[i].recall_event = recall[i].event
    end
    -- and save the chunk
    tab.save(sesh_data, norns.state.data.."sessions/"..number.."/"..name.."_session.data")
    print("finished writing '"..filename.."' as '"..name.."'")
  end

  params.action_read = function(filename)
    local loaded_file = io.open(filename, "r")
    if loaded_file then
      io.input(loaded_file)
      local pset_id = string.sub(io.read(), 4, -1)
      io.close(loaded_file)

      -- get pset number
      local pset_string = string.sub(filename, string.len(filename) - 6, -1)
      local number = pset_string:gsub(".pset", "")

      -- load buffer content
      softcut.buffer_clear ()
      softcut.buffer_read_mono(norns.state.data.."sessions/"..number.."/"..pset_id.."_buffer.wav", 0, 0, -1, 1, 1)

      -- load sesh data
      sesh_data = tab.load(norns.state.data.."sessions/"..number.."/"..pset_id.."_session.data")

      -- load clip data
      for i = 1, 8 do
        clip[i].name = sesh_data[i].clip_name
        clip[i].info = sesh_data[i].clip_info
        clip[i].reset = sesh_data[i].clip_reset
        clip[i].e = sesh_data[i].clip_e
        clip[i].l = sesh_data[i].clip_l
        clip[i].bpm = sesh_data[i].clip_bpm
      end
      -- load route data
      for i = 1, 5 do
        route[i].t5 = sesh_data[i].route_t5
        route[i].t6 = sesh_data[i].route_t6
        set_track_route(i)
      end
      -- load track data
      for i = 1, 6 do
        track[i].clip = sesh_data[i].track_clip
        set_clip(i, track[i].clip)
        track[i].tempo_map = sesh_data[i].track_tempo_map
        if track[i].tempo_map == 1 then clip_resize(i) end
        track[i].sel = sesh_data[i].track_sel
        track[i].fade = sesh_data[i].track_fade
        track[i].warble = sesh_data[i].track_warble
        e = {} e.t = eMUTE e.i = i e.mute = sesh_data[i].track_mute event(e)
        e = {} e.t = eREV e.i = i e.rev = sesh_data[i].track_rev event(e)
        e = {} e.t = eSPEED e.i = i e.speed = sesh_data[i].track_speed event(e)
        if sesh_data[i].track_loop == 1 then
          e = {}
          e.t = eLOOP
          e.i = i
          e.loop = 1
          e.loop_start = sesh_data[i].track_loop_start
          e.loop_end = sesh_data[i].track_loop_end
          event(e)
        elseif sesh_data[i].track_loop == 0 then
          track[i].loop = 0
          softcut.loop_start(i, clip[track[i].clip].s)
          softcut.loop_end(i, clip[track[i].clip].e)
        end
        set_rec(i)
      end
      -- load pattern data
      for i = 1, 8 do
        pattern[i].count = sesh_data[i].pattern_count
        pattern[i].time = {table.unpack(sesh_data[i].pattern_time)}
        pattern[i].event = {table.unpack(sesh_data[i].pattern_event)}
        pattern[i].time_factor = sesh_data[i].pattern_time_factor
        local e = {t = ePATTERN, i = i, action = "stop"} event(e)
        local e = {t = ePATTERN, i = i, action = "overdub_off"} event(e)
        if pattern[i].rec == 1 then
          local e = {t = ePATTERN, i = i, action = "rec_stop"} event(e)
        end
      end
      -- load recall data
      for i = 1, 4 do
        recall[i].has_data = sesh_data[i].recall_has_data
        recall[i].event = {table.unpack(sesh_data[i].recall_event)}
      end
      dirtyscreen = true
      dirtygrid = true
      print("finished reading '"..filename.."'")
    end
  end

  -- metros
  gridredrawtimer = metro.init(function() gridredraw() end, 1/30, -1)
  gridredrawtimer:start()

  screenredrawtimer = metro.init(function() screenredraw() end, 1/15, -1)
  screenredrawtimer:start()

  ledcounter = metro.init(function() ledpulse() end, 0.1, -1)
  ledcounter:start()

  warbletimer = metro.init(function() make_warble() end, 0.1, -1)
  warbletimer:start()

  tracktimer = metro.init(function() count_length() end, 0.01, -1)
  tracktimer:stop()

  -- threshold rec poll
  amp_in = {}
  local amp_src = {"amp_in_l", "amp_in_r"}
  for ch = 1, 2 do
    amp_in[ch] = poll.set(amp_src[ch])
    amp_in[ch].time = 0.01
    amp_in[ch].callback = function(val)
      if val > util.dbamp(params:get("rec_threshold")) / 10 then
        loop_point()
        clock.run(oneshot, track[oneshot_on].dur) -- when rec starts, clock coroutine starts
        tracktimer:start()
        thresh_rec()
        oneshot_rec = true
        amp_in[ch]:stop()
      end
    end
  end

  set_view(vREC)

  update_tempo()

  grid.add = draw_grid_connected

  params:bang()

  softcut.event_phase(phase)
  softcut.poll_start_phase()

  clock.run(clock_update_tempo)

  -- set "local e" to other than nil: workaround to an error that occured if thresh_rec() is called before any track is played
  for i = 1, 6 do
    track[i].play = 1
    track[i].play = 0
  end

  print("mlre loaded and ready. enjoy!")

end -- end of init

phase = function(n, x)
  local pp = ((x - clip[track[n].clip].s) / clip[track[n].clip].l)
  x = math.floor(pp * 16)
  if x ~= track[n].pos_grid then
    track[n].pos_grid = x
    if view == vCUT then dirtygrid = true end
    if view == vREC then dirtygrid = true end
    if view == vTRSP then dirtygrid = true end
  end
end

update_rate = function(i)
  local n = math.pow(2, track[i].speed + track[i].transpose + params:get(i.."detune"))
  if track[i].rev == 1 then n = -n end
  if track[i].tempo_map == 1 and params:get("t_map_mode") == 2 then
    local bpmmod = params:get("clock_tempo") / clip[track[i].clip].bpm
    n = n * bpmmod
  end
  softcut.rate(i, n)
end

-- user interface
gridkey_nav = function(x, z)
  if z == 1 then
    if x == 1 then
      if alt == 1 then
        if view ~= vCLIP then
          clear_clip(focus)
          show_message("clip "..track[focus].clip.." cleared")
        else
          clear_clip(clip_sel)
          show_message("clip "..track[clip_sel].clip.." cleared")
        end
      else
        set_view(vREC)
      end
    elseif x == 2 and alt == 0 then
        set_view(vCUT)
    elseif x == 3 then
      if alt == 1 then
        softcut.buffer_clear()
        show_message("buffers cleared")
      else
        set_view(vTRSP)
      end
    elseif x == 4 and alt == 0 then
      set_view(vLFO)
    elseif x > 4 and x < (params:get("event_slots") == 1 and 9 or 13) then
      local i = x - 4
      if alt == 1 then
        local e = {t = ePATTERN, i = i, action = "rec_stop"} event(e)
        local e = {t = ePATTERN, i = i, action = "stop"} event(e)
        local e = {t = ePATTERN, i = i, action = "clear"} event(e)
      elseif alt2 == 1 then
        if pattern[i].count == 0 then
          local e = {t = ePATTERN, i = i, action = "rec_start"} event(e)
        elseif pattern[i].rec == 1 then
          local e = {t = ePATTERN, i = i, action = "rec_stop"} event(e)
          local e = {t = ePATTERN, i = i, action = "start"} event(e)
        elseif pattern[i].overdub == 1 then
          local e = {t = ePATTERN, i = i, action = "overdub_off"} event(e)
        else
          local e = {t = ePATTERN, i = i, action = "overdub_on"} event(e)
        end
      elseif pattern[i].overdub == 1 then
        local e = {t = ePATTERN, i = i, action = "overdub_off"} event(e)
      elseif pattern[i].rec == 1 then
        local e = {t = ePATTERN, i = i, action = "rec_stop"} event(e)
        local e = {t = ePATTERN, i = i, action = "start"} event(e)
      elseif pattern[i].count == 0 then
        local e = {t = ePATTERN, i = i, action = "rec_start"} event(e)
      elseif pattern[i].play == 1 and pattern[i].overdub == 0 then
        local e = {t = ePATTERN, i = i, action = "stop"} event(e)
      else
        local e = {t = ePATTERN, i = i, action = "start"} event(e)
      end
    elseif x > 8 and x < 13 and not patterns_only then
      local i = x - 8
      if alt == 1 then
        recall[i].event = {}
        recall[i].recording = false
        recall[i].has_data = false
        recall[i].active = false
      elseif recall[i].recording == true then
        recall[i].recording = false
      elseif recall[i].has_data == false then
        recall[i].recording = true
      elseif recall[i].has_data == true then
        recall_exec(i)
        recall[i].active = true
      end
    elseif x == 15 and alt == 0 then
      quantize = 1 - quantize
      if quantize == 0 then
        clock.cancel(quantizer)
      else
        quantizer = clock.run(update_q_clock)
      end
    elseif x == 16 then alt = 1 if view == vLFO then dirtyscreen = true end
    elseif x == 15 and alt == 1 then set_view(vCLIP)
    elseif x == 14 and alt == 0 then alt2 = 1
    elseif x == 14 and alt == 1 then retrig()  -- set all playing tracks to pos 1
    elseif x == 13 and alt == 0 then stopall() -- stops all tracks
    elseif x == 13 and alt == 1 then altrun()  -- stops all running tracks and runs all stopped tracks if track[i].sel == 1
  end
  elseif z == 0 then
    if x == 16 then alt = 0 if view == vLFO then dirtyscreen = true end
    elseif x == 14 and alt == 0 then alt2 = 0 -- lock alt2 if alt2 released before alt is released
    elseif x > 8 and x < 13 and not patterns_only then recall[x - 8].active = false
    end
  end
  dirtygrid = true
end

gridredraw_nav = function()
  g:led(1, 1, 4)
  g:led(2, 1, 3)
  g:led(3, 1, 2)
  g:led(view, 1, 9)
  if alt == 1 and alt2 == 0 then g:led(16, 1, 15)
  elseif alt == 0 then g:led(16, 1, 9)
  end
  if quantize == 1 then g:led(15, 1, 9)
  elseif quantize == 0 then g:led(15, 1, 3)
  end
  if alt2 == 1 then g:led(14, 1, 9)
  elseif alt2 == 0 then g:led(14, 1, 2)
  end
  for i = 1, params:get("event_slots") == 1 and 4 or 8 do
    if pattern[i].rec == 1 then
      g:led(i + 4, 1, 15)
    elseif pattern[i].overdub == 1 then
      g:led(i + 4, 1, ledview)
    elseif pattern[i].play == 1 then
      g:led(i + 4, 1, 12)
    elseif pattern[i].count > 0 then
      g:led(i + 4, 1, 8)
    else
      g:led(i + 4, 1, 4)
    end
    if not patterns_only then
      local b = 3
      if recall[i].recording == true then
        b = 15
      elseif recall[i].active == true then
        b = 11
      elseif recall[i].has_data == true then
        b = 7
      end
      g:led(i + 8, 1, b)
    end
  end
end

---------------------- REC -------------------------

v.key[vREC] = function(n, z)
  if n == 2 and z == 1 then
    viewinfo[vREC] = 1 - viewinfo[vREC]
    dirtyscreen = true
  elseif n == 3 and z == 1 then
    pageNum = (pageNum % 3) + 1
    dirtyscreen = true
  end
end

v.enc[vREC] = function(n, d)
  if n == 1 then
    if key1_hold == 0 then
      pageNum = util.clamp(pageNum + d, 1, 3)
    elseif key1_hold == 1 then
      params:delta("output_level", d)
    end
    dirtyscreen = true
  end
  if pageNum == 1 then
    if viewinfo[vREC] == 0 then
      if n == 2 then
        params:delta(focus.."vol", d)
      elseif n == 3 then
        params:delta(focus.."pan", d)
      end
    else
      if n == 2 then
        params:delta(focus.."rec", d)
      elseif n == 3 then
        params:delta(focus.."dub", d)
      end
    end
  elseif pageNum == 2 then
    if viewinfo[vREC] == 0 then
      if n == 2 then
        params:delta(focus.."cutoff", d)
      elseif n == 3 then
        params:delta(focus.."filter_q", d)
      end
    else
      if n == 2 then
        params:delta(focus.."filter_type", d)
      elseif n == 3 then
        if params:get(focus.."filter_type") == 5 then
          return
        else
          params:delta(focus.."post_dry", d)
        end
      end
    end
  elseif pageNum == 3 then
    if viewinfo[vREC] == 0 then
      if n == 2 then
        params:delta(focus.."detune", d)
      elseif n == 3 then
        params:delta(focus.."transpose", d)
        if (view == vCUT or view == vTRSP) then dirtygrid = true end
      end
    else
      if n == 2 then
        params:delta(focus.."rate_slew", d)
      elseif n == 3 then
        params:delta(focus.."level_slew", d)
      end
    end
  end
end

v.redraw[vREC] = function()
  screen.clear()
  screen.level(15)
  screen.move(10, 16)
  screen.text("TRACK "..focus)
  local sel = viewinfo[vREC] == 0
  local mp = 98

  if pageNum == 1 then
    screen.level(15)
    screen.rect(mp + 3 ,11, 5, 5)
    screen.fill()
    screen.level(6)
    screen.rect(mp + 11, 12, 4, 4)
    screen.rect(mp + 18, 12, 4, 4)
    screen.stroke()

    screen.level(sel and 15 or 4)
    screen.move(10, 32)
    screen.text(params:string(focus.."vol"))
    screen.move(70, 32)
    screen.text(params:string(focus.."pan"))
    screen.move(10, 40)
    if track[focus].mute == 1 then
      screen.level(15)
      screen.text("[muted]")
    else
      screen.level(3)
      screen.text("volume")
    end
    screen.level(3)
    screen.move(70, 40)
    screen.text("pan")

    screen.level(not sel and 15 or 4)
    screen.move(10, 52)
    screen.text(params:string(focus.."rec"))
    screen.move(70, 52)
    screen.text(params:string(focus.."dub"))
    screen.level(3)
    screen.move(10, 60)
    screen.text("rec level")
    screen.move(70, 60)
    screen.text("dub level")

  elseif pageNum == 2 then
    screen.level(15)
    screen.rect(mp + 10, 11, 5, 5)
    screen.fill()
    screen.level(6)
    screen.rect(mp + 4, 12, 4, 4)
    screen.rect(mp + 18, 12, 4, 4)
    screen.stroke()

    screen.level(sel and 15 or 4)
    screen.move(10, 32)
    screen.text(params:string(focus.."cutoff"))
    screen.move(70, 32)
    screen.text(params:string(focus.."filter_q"))
    screen.level(3)
    screen.move(10, 40)
    screen.text("cutoff")
    screen.move(70, 40)
    screen.text("filter q")

    screen.level(not sel and 15 or 4)
    screen.move(10, 52)
    screen.text(params:string(focus.."filter_type"))
    screen.move(70, 52)
    if params:get(focus.."filter_type") == 5 then
      screen.text("-")
    else
      screen.text(params:string(focus.."post_dry"))
    end
    screen.level(3)
    screen.move(10, 60)
    screen.text("type")
    screen.move(70, 60)
    screen.text("dry level")

  elseif pageNum == 3 then
    screen.level(15)
    screen.rect(mp + 17, 11, 5, 5)
    screen.fill()
    screen.level(6)
    screen.rect(mp + 4, 12, 4, 4)
    screen.rect(mp + 11, 12, 4, 4)
    screen.stroke()

    screen.level(sel and 15 or 4)
    screen.move(10, 32)
    screen.text(params:string(focus.."detune"))
    screen.move(70, 32)
    screen.text(params:string(focus.."transpose"))
    screen.level(3)
    screen.move(10, 40)
    screen.text("detune")
    screen.move(70, 40)
    screen.text("transpose")

    screen.level(not sel and 15 or 4)
    screen.move(10, 52)
    screen.text(params:string(focus.."rate_slew"))
    screen.move(70, 52)
    screen.text(params:string(focus.."level_slew"))
    screen.level(3)
    screen.move(10, 60)
    screen.text("rate slew")
    screen.move(70, 60)
    screen.text("level slew")
  end

  if view_message ~= "" then
    screen.clear()
    screen.level(10)
    screen.rect(0, 25, 129, 16)
    screen.stroke()
    screen.level(15)
    screen.move(64, 25 + 10)
    screen.text_center(view_message)
  end

  screen.update()
end

v.gridkey[vREC] = function(x, y, z)
  if y == 1 then gridkey_nav(x, z)
  elseif y > 1 and y < 8 then
    if z == 1 then
      i = y - 1
      if x > 2 and x < 7 then
        if focus ~= i then
          focus = i
          dirtyscreen = true
        end
        if alt == 1 and alt2 == 0 then
          track[i].tempo_map = 1 - track[i].tempo_map
          clip_resize(i)
        elseif alt == 0 and alt2 == 1 then
          local n = 1 - track[i].buffer
          e = {} e.t = eBUFF e.i = i e.buffer = n + 1
          event(e)
        end
      elseif x == 1 and alt == 0 then
        rec_enable(i)
      elseif x == 1 and alt == 1 then
        track[i].fade = 1 - track[i].fade
        set_rec(i)
      elseif x == 2 then
        track[i].oneshot = 1 - track[i].oneshot
        for n = 1, 6 do
          if n ~= i then
            track[n].oneshot = 0
          end
        end
        oneshot_on = i
        arm_thresh_rec(i) -- amp_in poll starts
        update_cycle(i)  -- duration of oneshot is set (track[i].dur)
        if alt == 1 then -- if alt then go into autolength mode
          autolength = true
          e = {}
          e.t = eSTOP
          e.i = i
          event(e)
        else
          autolength = false
        end
      elseif x == 16 and alt == 0 and alt2 == 0 then
        toggle_playback(i)
      elseif x == 16 and alt == 0 and alt2 == 1 then
        track[i].sel = 1 - track[i].sel
      elseif x == 16 and alt == 1 and alt2 == 0 then
        local n = 1 - track[i].mute
        e = {} e.t = eMUTE e.i = i e.mute = n
        event(e)
      elseif x > 8 and x < 16 and alt == 0 then
        local n = x - 12
        e = {} e.t = eSPEED e.i = i e.speed = n
        event(e)
      elseif x == 8 and alt == 0 then
        local n = 1 - track[i].rev
        e = {} e.t = eREV e.i = i e.rev = n
        event(e)
      elseif x == 8 and alt == 1 then
        track[i].warble = 1 - track[i].warble
        update_rate(i)
      elseif x == 12 and alt == 1 then
        randomize(i)
      end
      dirtygrid = true
    end
  elseif y == 8 then -- cut for focused track
    if z == 1 and held[y] then heldmax[y] = 0 end
    held[y] = held[y] + (z * 2 - 1)
    if held[y] > heldmax[y] then heldmax[y] = held[y] end
    local i = focus
    if z == 1 then
      if alt2 == 1 then -- "hold mode" as on cut page
        heldmax[y] = x
        e = {}
        e.t = eLOOP
        e.i = i
        e.loop = 1
        e.loop_start = x
        e.loop_end = x
        event(e)
      elseif held[y] == 1 then
        first[y] = x
        local cut = x - 1
        e = {} e.t = eCUT e.i = i e.pos = cut
        event(e)
      elseif held[y] == 2 then
        second[y] = x
      end
    elseif z == 0 then
      if held[y] == 1 and heldmax[y] == 2 then
        e = {}
        e.t = eLOOP
        e.i = i
        e.loop = 1
        e.loop_start = math.min(first[y], second[y])
        e.loop_end = math.max(first[y], second[y])
        event(e)
      end
    end
  end
end

v.gridredraw[vREC] = function()
  g:all(0)
  g:led(3, focus + 1, 7)
  g:led(4, focus + 1, params:get(focus.."buffer_sel") == 1 and 7 or 3)
  g:led(5, focus + 1, params:get(focus.."buffer_sel") == 2 and 7 or 3)
  g:led(6, focus + 1, 3)
  for i = 1, 6 do
    local y = i + 1
    g:led(1, y, 3) -- rec
    if track[i].rec == 1 and track[i].fade == 1 then g:led(1, y, 15)  end
    if track[i].rec == 1 and track[i].fade == 0 then g:led(1, y, 15)  end
    if track[i].rec == 0 and track[i].fade == 1 then g:led(1, y, 6)  end
    if track[i].oneshot == 1 then g:led(2, y, ledview) end
    if track[i].tempo_map == 1 then g:led(6, y, 7) end
    g:led(8, y, track[i].warble == 1 and 8 or 5) -- reverse playback
    if track[i].rev == 1 and track[i].warble == 0 then g:led(8, y, 11) end
    if track[i].rev == 1 and track[i].warble == 1 then g:led(8, y, 15) end
    g:led(16, y, 3) -- start/stop
    if track[i].play == 1 and track[i].sel == 1 then g:led(16, y, 15) end
    if track[i].play == 1 and track[i].sel == 0 then g:led(16, y, 10) end
    if track[i].play == 0 and track[i].sel == 1 then g:led(16, y, 5) end
    g:led(12, y, 3) -- speed = 1
    g:led(12 + track[i].speed, y, 9)
  end
  if track[focus].loop == 1 then
    for x = track[focus].loop_start, track[focus].loop_end do
      g:led(x, 8, 4)
    end
  end
  if track[focus].play == 1 then
    if track[focus].rev == 0 then
      g:led((track[focus].pos_grid + 1) % 16, 8, 15)
    elseif track[focus].rev == 1 then
      if track[focus].loop == 1 then
        g:led((track[focus].pos_grid + 1) % 16, 8, 15)
      else
        g:led((track[focus].pos_grid + 2) % 16, 8, 15)
      end
    end
  end
  gridredraw_nav()
  g:refresh()
end

---------------------CUT-----------------------

v.key[vCUT] = v.key[vREC]
v.enc[vCUT] = v.enc[vREC]
v.redraw[vCUT] = v.redraw[vREC]

v.gridkey[vCUT] = function(x, y, z)
  if z == 1 and held[y] then heldmax[y] = 0 end
  held[y] = held[y] + (z * 2 - 1)
  if held[y] > heldmax[y] then heldmax[y] = held[y] end
  if y == 1 then gridkey_nav(x, z)
  elseif y == 8 and z == 1 then
    local i = focus
    if x >= 1 and x <=8 then e = {} e.t = eTRSP e.i = i e.trsp = x event(e) end
    if x >= 9 and x <=16 then e = {} e.t = eTRSP e.i = i e.trsp = x - 1 event(e) end
  else
    local i = y - 1
    if z == 1 then
      if focus ~= i then
        focus = i
        dirtyscreen = true
      end
      if alt == 1 and y < 8 then
        if track[i].play == 1 then
          e = {} e.t = eSTOP e.i = i
        else
          e = {} e.t = eSTART e.i = i
        end
        event(e)
      elseif alt2 == 1 and y < 8 then -- "hold mode"
        heldmax[y] = x
        e = {}
        e.t = eLOOP
        e.i = i
        e.loop = 1
        e.loop_start = x
        e.loop_end = x
        event(e)
      elseif y < 8 and held[y] == 1 then
        first[y] = x
        local cut = x-1
        e = {} e.t = eCUT e.i = i e.pos = cut
        event(e)
      elseif y < 8 and held[y] == 2 then
        second[y] = x
      end
    elseif z == 0 then
      if y < 8 and held[y] == 1 and heldmax[y] == 2 then
        e = {}
        e.t = eLOOP
        e.i = i
        e.loop = 1
        e.loop_start = math.min(first[y], second[y])
        e.loop_end = math.max(first[y], second[y])
        event(e)
      end
    end
  end
end

v.gridredraw[vCUT] = function()
  g:all(0)
  gridredraw_nav()
  for i = 1, 6 do
    if track[i].loop == 1 then
      for x = track[i].loop_start, track[i].loop_end do
        g:led(x, i + 1, 4)
      end
    end
    if track[i].play == 1 then
      if track[i].rev == 0 then
        g:led((track[i].pos_grid + 1) % 16, i + 1, 15)
      elseif track[i].rev == 1 then
        if track[i].loop == 1 then
          g:led((track[i].pos_grid + 1) % 16, i + 1, 15)
        else
          g:led((track[i].pos_grid + 2) % 16, i + 1, 15)
        end
      end
    end
  end
  g:led(8, 8, 6)
  g:led(9, 8, 6)
  if track[focus].transpose < 0 then
    g:led(params:get(focus.."transpose"), 8, 10)
  elseif track[focus].transpose > 0 then
    g:led(params:get(focus.."transpose") + 1, 8, 10)
  end
  g:refresh()
end

--------------------TRANSPOSE--------------------

v.key[vTRSP] = v.key[vREC]
v.enc[vTRSP] = v.enc[vREC]
v.redraw[vTRSP] = v.redraw[vREC]

v.gridkey[vTRSP] = function(x, y, z)
  if y == 1 then gridkey_nav(x, z)
  elseif y > 1 and y < 8 then
    if z == 1 then
      local i = y - 1
      if focus ~= i then
        focus = i
        dirtyscreen = true
      end
      if alt == 0 then
        if x >= 1 and x <=8 then e = {} e.t = eTRSP e.i = i e.trsp = x event(e) end
        if x >= 9 and x <=16 then e = {} e.t = eTRSP e.i = i e.trsp = x - 1 event(e) end
      end
      if alt == 1 and x > 7 and x < 10 then
        if track[i].play == 1 then
          e = {} e.t = eSTOP e.i = i
        else
          e = {} e.t = eSTART e.i = i
        end
        event(e)
      end
    end
  elseif y == 8 then -- cut for focused track
    if z == 1 and held[y] then heldmax[y] = 0 end
    held[y] = held[y] + (z * 2 - 1)
    if held[y] > heldmax[y] then heldmax[y] = held[y] end
    local i = focus
    if z == 1 then
      if alt2 == 1 then -- "hold" mode as on cut page
        heldmax[y] = x
        e = {}
        e.t = eLOOP
        e.i = i
        e.loop = 1
        e.loop_start = x
        e.loop_end = x
        event(e)
      elseif held[y] == 1 then
        first[y] = x
        local cut = x - 1
        e = {} e.t = eCUT e.i = i e.pos = cut
        event(e)
      elseif held[y] == 2 then
        second[y] = x
      end
    elseif z == 0 then
      if held[y] == 1 and heldmax[y] == 2 then
        e = {}
        e.t = eLOOP
        e.i = i
        e.loop = 1
        e.loop_start = math.min(first[y], second[y])
        e.loop_end = math.max(first[y], second[y])
        event(e)
      end
    end
  end
end

v.gridredraw[vTRSP] = function()
  g:all(0)
  gridredraw_nav()
  for i = 1, 6 do
    g:led(8, i + 1, 6)
    g:led(9, i + 1, 6)
    if track[i].transpose < 0 then
      g:led(params:get(i.."transpose"), i + 1, 10)
    elseif track[i].transpose > 0 then
      g:led(params:get(i.."transpose") + 1, i + 1, 10)
    end
  end
  if track[focus].loop == 1 then
    for x = track[focus].loop_start, track[focus].loop_end do
      g:led(x, 8, 4)
    end
  end
  if track[focus].play == 1 then
    if track[focus].rev == 0 then
      g:led((track[focus].pos_grid + 1) % 16, 8, 15)
    elseif track[focus].rev == 1 then
      if track[focus].loop == 1 then
        g:led((track[focus].pos_grid + 1) % 16, 8, 15)
      else
        g:led((track[focus].pos_grid + 2) % 16, 8, 15)
      end
    end
  end
  g:refresh()
end

---------------------- LFO -------------------------

v.key[vLFO] = function(n, z)
  if n == 2 and z == 1 then
    viewinfo[vLFO] = 1 - viewinfo[vLFO]
    dirtyscreen = true
  elseif n == 3 and z == 1 then
    pageLFO = (pageLFO % 6) + 1
    dirtyscreen = true
  end
end

v.enc[vLFO] = function(n, d)
  if n == 1 then
    if key1_hold == 0 then
      pageLFO = util.clamp(pageLFO + d, 1, 6)
    elseif key1_hold == 1 then
      params:delta("output_level", d)
    end
  end
  if viewinfo[vLFO] == 0 then
    if n == 2 then
      params:delta(pageLFO.."lfo_freq", d)
    elseif n == 3 then
      params:delta(pageLFO.."offset", d)
    end
  else
    if n == 2 then
      params:delta(pageLFO.."lfo_target", d)
    elseif n == 3 then
      if alt == 0 then
        params:delta(pageLFO.."lfo_shape", d)
      else
        params:delta(pageLFO.."lfo_range", d)
      end
    end
  end
end

v.redraw[vLFO] = function()
  screen.clear()
  screen.level(15)
  screen.move(10, 16)
  screen.text("LFO "..pageLFO)
  local sel = viewinfo[vLFO] == 0

  screen.level(sel and 15 or 4)
  screen.move(10, 32)
  screen.text(params:string(pageLFO.."lfo_freq"))
  screen.move(70, 32)
  screen.text(params:string(pageLFO.."offset"))
  screen.level(3)
  screen.move(10, 40)
  screen.text("freq")
  screen.move(70, 40)
  screen.text("offset")

  screen.level(not sel and 15 or 4)
  screen.move(10, 52)
  screen.text(params:string(pageLFO.."lfo_target"))
  screen.move(70, 52)
  if alt == 0 then
    screen.text(params:string(pageLFO.."lfo_shape"))
  else
    screen.text(params:string(pageLFO.."lfo_range"))
  end
  screen.level(3)
  screen.move(10, 60)
  screen.text("lfo target")
  screen.move(70, 60)
  if alt == 0 then
    screen.text("shape")
  else
    screen.text("range")
  end

  if view_message ~= "" then
    screen.clear()
    screen.level(10)
    screen.rect(0, 25, 129, 16)
    screen.stroke()
    screen.level(15)
    screen.move(64, 25 + 10)
    screen.text_center(view_message)
  end

  screen.update()
end

v.gridkey[vLFO] = function(x, y, z)
  if y == 1 then gridkey_nav(x, z) end
  if z == 1 then
    if y > 1 and y < 8 then
      local lfo_index = y - 1
      if pageLFO ~= lfo_index then
        pageLFO = lfo_index
      end
      if x == 1 then
        lfo[lfo_index].active = 1 - lfo[lfo_index].active
        if lfo[lfo_index].active == 1 then
          params:set(lfo_index .. "lfo", 2)
        else
          params:set(lfo_index .. "lfo", 1)
        end
      end
      if x > 1 and x <= 16 then
        params:set(lfo_index.."lfo_depth", (x - 2) * util.round_up((100 / 14), 0.1))
      end
    end
    if y == 8 then
      if x >= 1 and x <= 3 then
        if alt == 0 then
          params:set(pageLFO.."lfo_shape", x)
        elseif alt == 1 then
          params:set(pageLFO.."lfo_range", x)
        end
      end
      if x > 3 and x < 10 then
        trksel = 6 * (x - 4)
      end
      if x == 10 then
        params:set(pageLFO.."lfo_target", 1)
      end
      if x > 10 and x <= 16 then
        dstview = 1
        params:set(pageLFO.."lfo_target", trksel + x - 9)
      end
    end
  elseif z == 0 then
    if x > 10 and x <= 16 then
      dstview = 0
    end
  end
  dirtyscreen = true
  dirtygrid = true
end

v.gridredraw[vLFO] = function()
  g:all(0)
  gridredraw_nav()
  for i = 1, 6 do
    g:led(1, i + 1, params:get(i.."lfo") == 2 and math.floor(util.linlin( -1, 1, 6, 15, lfo[i].slope)) or 3) --nice one mat!
    local range = math.floor(util.linlin(0, 100, 2, 16, params:get(i.."lfo_depth")))
    g:led(range, i + 1, 7)
    for x = 2, range - 1 do
      g:led(x, i + 1, 3)
    end
    g:led(i + 3, 8, 4)
    g:led(i + 10, 8, 4)
  end
  if alt == 0 then
    g:led(params:get(pageLFO.."lfo_shape"), 8, 5)
  elseif alt == 1 then
    g:led(params:get(pageLFO.."lfo_range"), 8, 5)
  end
  g:led(trksel / 6 + 4, 8, 12)
  if dstview == 1 then
    g:led((params:get(pageLFO.."lfo_target") + 9) - trksel, 8, 12)
  end
  g:refresh()
end

---------------------CLIP-----------------------

clip_actions = {"load", "clear", "save", "reset"}
clip_action = 1
clip_sel = 1
resize_values = {1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 42}
resize_options = {"1/4", "2/4", "3/4", "4/4", "6/4", "8/4", "12/4", "16/4", "24/4", "32/4", "max"}

function fileselect_callback(path, c)
  local buffer = params:get(c.."buffer_sel")
  if path ~= "cancel" and path ~= "" then
    local ch, len = audio.file_info(path)
    if ch > 0 and len > 0 then
      print("file: "..path.." "..clip[track[c].clip].s)
      softcut.buffer_read_mono(path, 0, clip[track[c].clip].s, max_cliplength, 1, buffer)
      local l = math.min(len / 48000, max_cliplength)
      local r_idx = params:get(track[c].clip.."clip_length")
      local r_val = resize_values[r_idx]
      set_clip_length(track[c].clip, l, r_val)
      set_clip(c, track[c].clip)
      clip[track[c].clip].name = path:match("[^/]*$")
      clip[track[c].clip].info = "length "..string.format("%.2f", l).."s"
      clip[track[c].clip].reset = l
      update_rate(c)
    else
      print("not a sound file")
    end
  end
  screenredrawtimer:start()
  dirtyscreen = true
end

function textentry_callback(txt)
  local buffer = params:get(clip_sel.."buffer_sel")
  if txt then
    local c_start = clip[track[clip_sel].clip].s
    local c_len = clip[track[clip_sel].clip].l
    print("SAVE " .. _path.audio .. "mlre/" .. txt .. ".wav", c_start, c_len)
    util.make_dir(_path.audio .. "mlre")
    softcut.buffer_write_mono(_path.audio.."mlre/"..txt..".wav", c_start, c_len, buffer)
    clip[track[clip_sel].clip].name = txt
  else
    print("save cancel")
  end
  screenredrawtimer:start()
  dirtyscreen = true
end

v.key[vCLIP] = function(n, z)
  if key1_hold == 0 then
    if n == 2 and z == 0 then
      if clip_actions[clip_action] == "load" then
        screenredrawtimer:stop()
        fileselect.enter(os.getenv("HOME").."/dust/audio", function(n) fileselect_callback(n, clip_sel) end)
      elseif clip_actions[clip_action] == "clear" then
        clear_clip(clip_sel)
        dirtyscreen = true
      elseif clip_actions[clip_action] == "save" then
        screenredrawtimer:stop()
        textentry.enter(textentry_callback, "mlre-" .. (math.random(9000)+1000))
      elseif clip_actions[clip_action] == "reset" then
        clip_reset(clip_sel)
        dirtyscreen = true
      end
    elseif n == 3 and z == 1 then
      clip_resize(clip_sel)
      dirtyscreen = true
    end
  end
end

v.enc[vCLIP] = function(n, d)
  if key1_hold == 0 then
    if n == 2 then
      clip_action = util.clamp(clip_action + d, 1, 4)
    elseif n == 3 then
      params:delta(track[clip_sel].clip.."clip_length", d)
    end
  else
    if n == 2 then
      params:delta(clip_sel.."send_track5", d)
    elseif n == 3 then
      params:delta(clip_sel.."send_track6", d)
    end
  end
  dirtyscreen = true
end

local function truncateMiddle(str, maxLength, separator)
  maxLength = maxLength or 30
  separator = separator or "..."

  if (maxLength < 1) then return str end
  if (string.len(str) <= maxLength) then return str end
  if (maxLength == 1) then return string.sub(str, 1, 1) .. separator end

  midpoint = math.ceil(string.len(str) / 2)
  toremove = string.len(str) - maxLength
  lstrip = math.ceil(toremove / 2)
  rstrip = toremove - lstrip

  return string.sub(str, 1, midpoint - lstrip) .. separator .. string.sub(str, 1 + midpoint + rstrip)
end

v.redraw[vCLIP] = function()
  screen.clear()
  screen.level(15)
  screen.move(10, 16)
  screen.text("TRACK "..clip_sel)

  if key1_hold == 0 or clip_sel == 6 then
    screen.move(10, 32)
    screen.text(">> "..truncateMiddle(clip[track[clip_sel].clip].name, 18))
    screen.level(4)
    screen.move(64, 46)
    screen.text_center("-- "..clip[track[clip_sel].clip].info.." --")
    screen.move(10, 60)
    screen.text("CLIP "..track[clip_sel].clip)
    screen.level(15)
    screen.move(38, 60)
    screen.text(clip_actions[clip_action])

    screen.level(15)
    screen.move(95, 60)
    screen.text_right(params:string(track[clip_sel].clip.."clip_length"))
    screen.level(4)
    screen.move(100, 60)
    screen.text("length")
  elseif clip_sel < 6 then
    if clip_sel < 5 then
      screen.level(15)
      screen.move(38, 32)
      screen.text_center(params:string(clip_sel.."send_track5"))
      screen.level(3)
      screen.move(38, 42)
      screen.text_center("send level")
      screen.move(38, 50)
      screen.text_center("to track 5")
    else
      screen.level(3)
      screen.move(38, 42)
      screen.text_center("---")
    end
    screen.level(15)
    screen.move(90, 32)
    screen.text_center(params:string(clip_sel.."send_track6"))
    screen.level(3)
    screen.move(90, 42)
    screen.text_center("send level")
    screen.move(90, 50)
    screen.text_center("to track 6")
  end

  screen.level(15)
  screen.move(116, 16)
  local d = params:get("quant_div")
  screen.text_right(div_options[d])
  screen.level(4)
  screen.move(120, 16)
  screen.text("Q")

  if view_message ~= "" then
    screen.clear()
    screen.level(10)
    screen.rect(0, 25, 129, 16)
    screen.stroke()
    screen.level(15)
    screen.move(64, 25 + 10)
    screen.text_center(view_message)
  end

  screen.update()
end

v.gridkey[vCLIP] = function(x, y, z)
  if y == 1 then gridkey_nav(x, z)
  elseif z == 1 then
    if y > 1 and y < 8 and x < 9 then
      clip_sel = y - 1
      if alt2 == 0 then
        if x ~= track[clip_sel].clip then
          set_clip(clip_sel, x)
        end
      elseif alt2 == 1 then
        copy_buffer(clip_sel)
      end
    elseif y > 1 and y < 8 and x > 9 and x < 14 then
      local i = y - 1
      params:set(i.."input_options", x - 9)
    elseif y > 1 and y < 6 and x == 15 then
      local i = y - 1
      route[i].t5 = 1 - route[i].t5
      set_track_route(i)
    elseif y > 1 and y < 7 and x == 16 then
      local i = y - 1
      route[i].t6 = 1 - route[i].t6
      set_track_route(i)
    elseif y == 7 and x == 15 then
      route.adc = 1 - route.adc
      set_track_source()
    elseif y == 7 and x == 16 then
      route.tape = 1 - route.tape
      set_track_source()
    elseif y == 8 and x < 9 then
      params:set("quant_div", x)
    end
    dirtyscreen = true
    dirtygrid = true
  end
end

v.gridredraw[vCLIP] = function()
  g:all(0)
  gridredraw_nav()
  for i = 1, 8 do g:led(i, clip_sel + 1, 4) end
  for i = 1, 6 do g:led(track[i].clip, i + 1, 10) end
  for i = 10, 13 do
    for j = 2, 7 do
      g:led(i, j, 3)
    end
  end
  for i = 1, 6 do
    g:led(params:get(i.."input_options") + 9, i + 1, 9)
  end
  for i = 15, 16 do
    for j = 2, 5 do
      g:led(i, j, 2)
    end
  end
  g:led(16, 6, 2)
  for i = 1, 4 do
    local y = i + 1
    if route[i].t5 == 1 then
      g:led(15, y, 9)
    end
  end
  for i = 1, 5 do
    local y = i + 1
    if route[i].t6 == 1 then
      g:led(16, y, 9)
    end
  end
  g:led(15, 7, 5) g:led(16, 7, 5)
  if route.adc == 1 then
    g:led(15, 7, 11)
  end
  if route.tape == 1 then
    g:led(16, 7, 11)
  end
  for i = 1, 8 do
    g:led(i, 8, 4)
  end
  g:led(params:get("quant_div"), 8, 10)
  g:refresh()
end

function draw_grid_connected()
  dirtygrid = true
  gridredraw()
end

function cleanup()
  for i = 1, 8 do
    pattern[i]:stop()
    pattern[i] = nil
  end
  grid.add = function() end
end
