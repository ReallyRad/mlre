-- layout for grid one / 128 keys 

local grd_one = {}

function grd_one.nav(x, z)
  if z == 1 then
    if x == 1 then
      if alt == 1 then
        clear_splice(track_focus)
      else
        set_view(vREC)
      end
    elseif x == 2 then
      if alt == 1 then
        clear_tape(track_focus)
      else
        set_view(vCUT)
        cutview_hold = true
      end
    elseif x == 3 then
      if alt == 1 then
        clear_buffers()
        show_message("buffers cleared")
      else
        set_view(vTRSP)
      end
    elseif x == 4 and alt == 0 then
      if view == vLFO then
        set_view(vENV)
      else
        set_view(vLFO)
      end
    elseif x > 4 and x < (params:get("slot_assign") == 1 and 9 or 13) and params:get("slot_assign") ~= 3 then
      local i = x - 4
      if alt == 1 then
        local e = {t = ePATTERN, i = i, action = "rec_stop"} event(e)
        local e = {t = ePATTERN, i = i, action = "stop"} event(e)
        local e = {t = ePATTERN, i = i, action = "clear"} event(e)
      elseif mod == 1 then
        if pattern[i].count == 0 then
          local e = {t = ePATTERN, i = i, action = "rec_start"} event(e)
        elseif pattern[i].rec == 1 then
          local e = {t = ePATTERN, i = i, action = "rec_stop"} event(e)
          local e = {t = ePATTERN, i = i, action = "start"} event(e)
        elseif pattern[i].overdub == 1 then
          local e = {t = ePATTERN, i = i, action = "overdub_undo"} event(e)
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
    elseif x > (params:get("slot_assign") == 3 and 4 or 8) and x < 13 and params:get("slot_assign") ~= 2 then
      local i = x - 4
      if snapshot_mode then
        if alt == 1 then
          snap[i].data = false
          snap[i].active = false
        elseif alt == 0 then
          if not snap[i].data then
            save_snapshot(i)
          elseif snap[i].data then
            load_snapshot(i)
            snap[i].active = true
          end
        end
      elseif not snapshot_mode then
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
      end
    elseif x == 15 and alt == 0 and mod == 0 then
      quantizing = not quantizing
      if quantizing then
        quantizer = clock.run(update_q_clock)
        downbeat = clock.run(barpulse)
        quater = clock.run(beatpulse)
      else
        clock.cancel(quantizer)
        clock.cancel(downbeat)
        clock.cancel(quater)
      end
      elseif x == 16 then alt = 1 if view == vLFO then dirtyscreen = true end
      elseif x == 15 and alt == 1 then set_view(vTAPE) render_splice()
      elseif x == 15 and mod == 1 then set_view(vPATTERNS)
      elseif x == 14 and alt == 0 then mod = 1
      elseif x == 14 and alt == 1 then retrig()  -- set all playing tracks to pos 1
      elseif x == 13 and alt == 0 then stopall() -- stops all tracks
      elseif x == 13 and alt == 1 then altrun()  -- stops all running tracks and runs all stopped tracks if track[i].sel == 1
    end
  elseif z == 0 then
    if x == 2 then cutview_hold = false end
    if x == 16 then alt = 0 if view == vLFO then dirtyscreen = true end
    elseif x == 14 and alt == 0 then mod = 0 -- lock mod if mod released before alt is released
    elseif x > (params:get("slot_assign") == 3 and 4 or 8) and x < 13 and params:get("slot_assign") ~= 2 then
      if snapshot_mode then
        snap[x - 4].active = false
      else
        recall[x - 4].active = false
      end
    end
  end
  dirtygrid = true
end

function grd_one.drawnav()
  g:led(1, 1, 4) -- vREC
  g:led(2, 1, 3) -- vCUT
  g:led(3, 1, 2) -- vTRSP
  g:led(view, 1, 9) -- track_focus
  g:led(16, 1, alt == 1 and 15 or 9) -- alt
  g:led(15, 1, quantizing and (flash_bar and 15 or (flash_beat and 10 or 7)) or 3) -- Q flash
  g:led(14, 1, mod == 1 and 9 or 2) -- mod
  for i = 1, (params:get("slot_assign") == 1 and 4 or 8) do
    if params:get("slot_assign") ~= 3 then
      if pattern[i].rec == 1 then
        g:led(i + 4, 1, 15)
      elseif pattern[i].overdub == 1 then
        g:led(i + 4, 1, pulse_key_fast)
      elseif pattern[i].play == 1 then
        g:led(i + 4, 1, pattern[i].flash and 15 or 12)
      elseif pattern[i].count > 0 then
        g:led(i + 4, 1, 8)
      else
        g:led(i + 4, 1, 4)
      end
    end
  end
  for i = (params:get("slot_assign") == 1 and 5 or 1), 8 do
    if params:get("slot_assign") ~= 2 then
      local b = 3
      if snapshot_mode then
        if snap[i].active == true then
          b = 11
        elseif snap[i].data == true then
          b = 7
        end
      else
        if recall[i].recording == true then
          b = 15
        elseif recall[i].active == true then
          b = 11
        elseif recall[i].has_data == true then
          b = 7
        end
      end
      g:led(i + 4, 1, b)
    end
  end
end

function grd_one.cutfocus_keys(x, z)
  local row = track_focus + 1
  local i = track_focus
  if z == 1 and held[row] then heldmax[row] = 0 end
  held[row] = held[row] + (z * 2 - 1)
  if held[row] > heldmax[row] then heldmax[row] = held[row] end
  if z == 1 then
    if alt == 1 and mod == 0 then
      toggle_playback(i)
    elseif mod == 1 then -- "hold mode" as on cut page
      heldmax[row] = x
      local e = {}
      e.t = eLOOP
      e.i = i
      e.loop = 1
      e.loop_start = x
      e.loop_end = x
      event(e)
      enc2_wait = false
    elseif held[row] == 1 then -- cut at pos
      if not track[i].loaded then
        load_track_tape(i)
      end
      first[row] = x
      local cut = x - 1
      local e = {} e.t = eCUT e.i = i e.pos = cut event(e)
      if params:get(i.."adsr_active") == 2 then
        local e = {} e.t = eGATEON e.i = i event(e)
      end
    elseif held[row] == 2 then -- second keypress
      second[row] = x
    end
  elseif z == 0 then
    if held[row] == 1 and heldmax[row] == 2 then -- if two keys held at release then loop
      local e = {}
      e.t = eLOOP
      e.i = i
      e.loop = 1
      e.loop_start = math.min(first[row], second[row])
      e.loop_end = math.max(first[row], second[row])
      event(e)
      enc2_wait = false
    end
    if params:get(i.."play_mode") == 3 and track[i].loop == 0 and params:get(i.."adsr_active") == 1 then
      local e = {} e.t = eSTOP e.i = i event(e)
    end
    if params:get(i.."adsr_active") == 2 and track[i].loop == 0 then
      local e = {} e.t = eGATEOFF e.i = i event(e)
    end
  end
end

function grd_one.cutfocus_draw()
  if track[track_focus].loop == 1 then
    for x = math.floor(track[track_focus].loop_start), math.ceil(track[track_focus].loop_end) do
      g:led(x, 8, 4)
    end
  end
  if track[track_focus].play == 1 then
    g:led(track[track_focus].pos_grid, 8, 15)
  end
end


function grd_one.rec_keys(x, y, z)
  if y == 1 then grd_one.nav(x, z)
  elseif y > 1 and y < 8 then
    local i = y - 1
    if z == 1 then
      if x > 2 and x < 7 then
        if track_focus ~= i then
          track_focus = i
          arc_track_focus = track_focus
          dirtyscreen = true
        end
        if alt == 1 and mod == 0 then
          params:set(i.."tempo_map_mode", util.wrap(params:get(i.."tempo_map_mode") + 1, 1, 3))
        elseif alt == 0 and mod == 1 then
          params:set(track_focus.."buffer_sel", track[track_focus].side == 0 and 2 or 1)
        end
      elseif x == 1 and alt == 0 then
        toggle_rec(i)
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
        armed_track = i
        arm_thresh_rec(i) -- amp_in poll starts
        update_dur(i)  -- duration of oneshot is set
        if alt == 1 then -- if alt then go into autolength mode and stop track
          autolength = true
          local e = {}
          e.t = eSTOP
          e.i = i
          event(e)
        else
          autolength = false
        end
      elseif x == 16 and alt == 0 and mod == 0 then
        toggle_playback(i)
      elseif x == 16 and alt == 0 and mod == 1 then
        track[i].sel = 1 - track[i].sel
      elseif x == 16 and alt == 1 and mod == 0 then
        local n = 1 - track[i].mute
        local e = {} e.t = eMUTE e.i = i e.mute = n
        event(e)
      elseif x > 8 and x < 16 and alt == 0 then
        local n = x - 12
        local e = {} e.t = eSPEED e.i = i e.speed = n
        event(e)
      elseif x == 8 and alt == 0 then
        local n = 1 - track[i].rev
        local e = {} e.t = eREV e.i = i e.rev = n
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
    grd_one.cutfocus_keys(x, z)
  end
end

function grd_one.rec_draw()
  g:all(0)
  --g:led(3, track_focus + 1, 7)
  g:led(4, track_focus + 1, params:get(track_focus.."buffer_sel") == 1 and 7 or 3)
  g:led(5, track_focus + 1, params:get(track_focus.."buffer_sel") == 2 and 7 or 3)
  for i = 1, 6 do
    local y = i + 1
    g:led(1, y, track[i].rec == 1 and 15 or (track[i].fade == 1 and 7 or 3)) -- rec key
    g:led(2, y, track[i].oneshot == 1 and pulse_key_fast or 0)
    g:led(3, y, track[i].loaded and (track_focus == i and 7 or 0) or pulse_key_slow)
    g:led(6, y, track[i].tempo_map == 1 and 7 or (track[i].tempo_map == 2 and 12 or (track_focus == i and 3 or 0)))
    g:led(8, y, track[i].rev == 1 and (track[i].warble == 1 and 15 or 11) or (track[i].warble == 1 and 8 or 4))
    g:led(16, y, 3) -- start/stop
    if track[i].mute == 1 then
      g:led(16, y, track[i].play == 0 and (track[i].sel == 0 and pulse_key_slow - 4 or pulse_key_slow) or (track[i].sel == 0 and pulse_key_slow or pulse_key_slow + 3))
    elseif track[i].play == 1 and track[i].sel == 1 then
      g:led(16, y, 15)
    elseif track[i].play == 1 and track[i].sel == 0 then
      g:led(16, y, 10)
    elseif track[i].play == 0 and track[i].sel == 1 then
      g:led(16, y, 5)
    end
    g:led(12, y, 3)
    g:led(12 + track[i].speed, y, 9)
  end
  grd_one.cutfocus_draw()
  grd_one.drawnav()
  g:refresh()
end

function grd_one.cut_keys(x, y, z)
  if z == 1 and held[y] then heldmax[y] = 0 end
  held[y] = held[y] + (z * 2 - 1)
  if held[y] > heldmax[y] then heldmax[y] = held[y] end
  if y == 1 then grd_one.nav(x, z)
  elseif y == 8 and z == 1 then
    local i = track_focus
    if mod == 0 then
      if x >= 1 and x <=8 then local e = {} e.t = eTRSP e.i = i e.val = x event(e) end
      if x >= 9 and x <=16 then local e = {} e.t = eTRSP e.i = i e.val = x - 1 event(e) end
    elseif mod == 1 then
      if x == 8 then
        local n = util.clamp(track[i].speed - 1, -3, 3) local e = {} e.t = eSPEED e.i = i e.speed = n event(e)
      elseif x == 9 then
        local n = util.clamp(track[i].speed + 1, -3, 3) local e = {} e.t = eSPEED e.i = i e.speed = n event(e)
      end
    end
  else
    local i = y - 1
    if z == 1 then
      if track_focus ~= i then
        track_focus = i
        arc_track_focus = track_focus
        dirtyscreen = true
      end
      if alt == 1 and y < 8 then
        toggle_playback(i)
      elseif mod == 1 and y < 8 then -- "hold mode"
        heldmax[y] = x
        local e = {}
        e.t = eLOOP
        e.i = i
        e.loop = 1
        e.loop_start = x
        e.loop_end = x
        event(e)
        enc2_wait = false
      elseif y < 8 and held[y] == 1 then
        if not track[i].loaded then
          load_track_tape(i)
        end
        first[y] = x
        local cut = x - 1
        local e = {} e.t = eCUT e.i = i e.pos = cut event(e)
        if params:get(i.."adsr_active") == 2 then
          local e = {} e.t = eGATEON e.i = i event(e)
        end
      elseif y < 8 and held[y] == 2 then
        second[y] = x
      end
    elseif z == 0 then
      if y < 8 then 
        if held[y] == 1 and heldmax[y] == 2 then
          local e = {}
          e.t = eLOOP
          e.i = i
          e.loop = 1
          e.loop_start = math.min(first[y], second[y])
          e.loop_end = math.max(first[y], second[y])
          event(e)
          enc2_wait = false
        else
          if params:get(i.."play_mode") == 3 and track[i].loop == 0 and params:get(i.."adsr_active") == 1 then
            local e = {} e.t = eSTOP e.i = i event(e)
          end
          if params:get(i.."adsr_active") == 2 and track[i].loop == 0 then
            local e = {} e.t = eGATEOFF e.i = i event(e)
          end
        end
      end
    end
  end
end

function grd_one.cut_draw()
  g:all(0)
  grd_one.drawnav()
  for i = 1, 6 do
    if track[i].loop == 1 then
      for x = math.floor(track[i].loop_start), math.ceil(track[i].loop_end) do
        g:led(x, i + 1, 4)
      end
    end
    if track[i].play == 1 then
      g:led(track[i].pos_grid, i + 1, track_focus == i and 15 or 10)
    end
  end
  g:led(8, 8, 6)
  g:led(9, 8, 6)
  if track[track_focus].transpose < 0 then
    g:led(params:get(track_focus.."transpose"), 8, 10)
  elseif track[track_focus].transpose > 0 then
    g:led(params:get(track_focus.."transpose") + 1, 8, 10)
  end
  g:refresh()
end

function grd_one.trsp_keys(x, y, z)
  if y == 1 then grd_one.nav(x, z)
  elseif y > 1 and y < 8 then
    if z == 1 then
      local i = y - 1
      if track_focus ~= i then
        track_focus = i
        arc_track_focus = track_focus
        dirtyscreen = true
      end
      if alt == 0 and mod == 0 then
        if x >= 1 and x <=8 then local e = {} e.t = eTRSP e.i = i e.val = x event(e) end
        if x >= 9 and x <=16 then local e = {} e.t = eTRSP e.i = i e.val = x - 1 event(e) end
      end
      if alt == 1 and x > 7 and x < 10 then
        toggle_playback(i)
      end
      if mod == 1 then
        if x == 8 then
          local n = util.clamp(track[i].speed - 1, -3, 3) local e = {} e.t = eSPEED e.i = i e.speed = n event(e)
        elseif x == 9 then
          local n = util.clamp(track[i].speed + 1, -3, 3) local e = {} e.t = eSPEED e.i = i e.speed = n event(e)
        end
      end
    end
  elseif y == 8 then -- cut for focused track
    grd_one.cutfocus_keys(x, z)
  end
end

function grd_one.trsp_draw()
  g:all(0)
  grd_one.drawnav()
  for i = 1, 6 do
    g:led(8, i + 1, track_focus == i and 10 or 6)
    g:led(9, i + 1, track_focus == i and 10 or 6)
    if track[i].transpose < 0 then
      g:led(params:get(i.."transpose"), i + 1, 10)
    elseif track[i].transpose > 0 then
      g:led(params:get(i.."transpose") + 1, i + 1, 10)
    end
  end
  grd_one.cutfocus_draw()
  g:refresh()
end

function grd_one.lfo_keys(x, y, z)
  if y == 1 then grd_one.nav(x, z) end
  if z == 1 then
    if y > 1 and y < 8 then
      local i = y - 1
      if lfo_focus ~= i then
        lfo_focus = i
        arc_lfo_focus = lfo_focus
      end
      if x == 1 then
        lfo[lfo_focus].active = 1 - lfo[lfo_focus].active
        if lfo[lfo_focus].active == 1 then
          params:set(lfo_focus .. "lfo_state", 2)
        else
          params:set(lfo_focus .. "lfo_state", 1)
        end
      end
      if x > 1 and x <= 16 then
        params:set(lfo_focus.."lfo_depth", (x - 2) * util.round_up((100 / 14), 0.1))
      end
    end
    if y == 8 then
      if x >= 1 and x <= 3 then
        if alt == 0 and shift == 0 then
          params:set(lfo_focus.."lfo_shape", x)
        elseif (alt == 1 or shift == 1) then
          params:set(lfo_focus.."lfo_range", x)
        end
      end
      if x > 3 and x < 10 then
        lfo_trksel = 6 * (x - 4)
      end
      if x == 10 then
        params:set(lfo_focus.."lfo_target", 1)
      end
      if x > 10 and x <= 16 then
        lfo_dstview = 1
        params:set(lfo_focus.."lfo_target", lfo_trksel + x - 9)
      end
    end
  elseif z == 0 then
    if x > 10 and x <= 16 then
      lfo_dstview = 0
    end
  end
  dirtyscreen = true
  dirtygrid = true
end

function grd_one.lfo_draw()
  g:all(0)
  grd_one.drawnav()
  for i = 1, 6 do
    g:led(1, i + 1, params:get(i.."lfo_state") == 2 and math.floor(util.linlin( -1, 1, 6, 15, lfo[i].slope)) or 3) --nice one mat!
    local range = math.floor(util.linlin(0, 100, 2, 16, params:get(i.."lfo_depth")))
    g:led(range, i + 1, 7)
    for x = 2, range - 1 do
      g:led(x, i + 1, 3)
    end
    g:led(i + 3, 8, 4)
    g:led(i + 10, 8, 4)
  end
  if (alt == 0 and shift == 0) then
    g:led(params:get(lfo_focus.."lfo_shape"), 8, 5)
  elseif (alt == 1 or shift == 1) then
    g:led(params:get(lfo_focus.."lfo_range"), 8, 5)
  end
  g:led(lfo_trksel / 6 + 4, 8, 12)
  if lfo_dstview == 1 then
    g:led((params:get(lfo_focus.."lfo_target") + 9) - lfo_trksel, 8, 12)
  end
  g:refresh()
end

function grd_one.env_keys(x, y, z)
  if y == 1 then grd_one.nav(x, z) end
  if z == 1 then
    if y > 1 and y < 8 then
      local i = y - 1
      if x == 1 then
        state = params:get(i.."adsr_active") == 1 and 2 or 1
        params:set(i.."adsr_active", state)
      elseif x == 2 then
        if env_focus ~= i then
          env_focus = i
        end
        if params:get(i.."adsr_active") == 2 then
          local e = {} e.t = eGATEON e.i = i event(e)
        end
      end
    end
  elseif z == 0 then
    if y > 1 and y < 8 then
      local i = y - 1
      if x == 2 then
        if params:get(i.."adsr_active") == 2 then
          local e = {} e.t = eGATEOFF e.i = i event(e)
        end
      end
    end
  end
  dirtyscreen = true
  dirtygrid = true
end

function grd_one.env_draw()
  g:all(0)
  grd_one.drawnav()
  for i = 1, 6 do
    g:led(1, i + 1, params:get(i.."adsr_active") == 2 and 10 or 3)
    local range = math.floor(util.linlin(1, 100, 2, 16, params:get(i.."vol") * 100))
    if params:get(i.."adsr_active") == 2 then
      g:led(range, i + 1, 7)
      for x = 2, range - 1 do
        g:led(x, i + 1, 3)
      end
    end
    g:led(2, i + 1, env_focus == i and 10 or 6)
  end
  g:refresh()
end

function grd_one.pattern_keys(x, y, z)
  if y == 1 then grd_one.nav(x, z) end
  if z == 1 then
    if x > 1 and x < 4 then
      if y > 2 and y < 6 then
        params:set("slot_assign", y - 2)
      elseif y == 6 then
        snapshot_mode = not snapshot_mode
      end
    elseif x > 4 and x < 13 then
      local i = x - 4
      -- set track_focus
      if y < 7 then
        if pattern_focus ~= i then
          pattern_focus = i
        end
      end
      -- set params
      if y == 2 then
        pattern[i].synced = not pattern[i].synced
      elseif y == 3 then
        if pattern[i].synced then 
          params:set("patterns_countin"..i, pattern[i].count_in == 1 and 2 or 1)
        end
      elseif y == 7 and pattern[pattern_focus].synced then
        params:set("patterns_barnum"..pattern_focus, i)
      elseif y == 8 and pattern[pattern_focus].synced then
        params:set("patterns_barnum"..pattern_focus, i + 8)
      end
    elseif x > 13 and x < 16 then
      if y > 2 and y < 7 then
        local val = (y - 2) + (x - 14) * 4
        params:set("quant_rate", val)
      end
    end
  end
  dirtyscreen = true
  dirtygrid = true
end

function grd_one.pattern_draw()
  g:all(0)
  grd_one.drawnav()
  for i = 1, 2 do
    local x = i + 1
    g:led(x, 3, params:get("slot_assign") == 1 and 10 or 4)
    g:led(x, 4, params:get("slot_assign") == 2 and 10 or 4)
    g:led(x, 5, params:get("slot_assign") == 3 and 10 or 4)
    g:led(x, 6, snapshot_mode and 4 or 10)
  end
  for i = 1, 8 do
    g:led(i + 4, 2, pattern[i].synced and 10 or 4)
    g:led(i + 4, 3, pattern[i].synced and (pattern[i].count_in == 4 and 6 or 2) or 0)
    g:led(i + 4, 4, pattern_focus == i and 8 or 0)
    g:led(i + 4, 5, pattern_focus == i and 8 or 0)
    g:led(i + 4, 7, pattern[pattern_focus].synced and (params:get("patterns_barnum"..pattern_focus) == i and 15 or 8) or 4)
    g:led(i + 4, 8, pattern[pattern_focus].synced and (params:get("patterns_barnum"..pattern_focus) == i + 8 and 15 or 8) or 4)
  end
  for i = 1, 2 do
    local x = i + 13
    for j = 1, 4 do
      local y = j + 2
      g:led(x, y, params:get("quant_rate") == (y - 2) + (x - 14) * 4 and 10 or 4)
    end
  end
  g:refresh()
end

function grd_one.tape_keys(x, y, z)
  if y == 1 then grd_one.nav(x, z)
  elseif y > 1 and y < 8 then
    local i = y - 1
    if x < 9 and z == 1 then
      track_focus = i
      arc_track_focus = track_focus
      track[track_focus].splice_focus = x
      arc_splice_focus = track[track_focus].splice_focus
      if alt == 1 and mod == 0 then
        local e = {} e.t = eSPLICE e.i = track_focus e.active = x event(e)
      elseif alt == 0 and mod == 1 then
        local src = track[track_focus].side == 0 and 1 or 2
        local dst = track[track_focus].side == 0 and 2 or 1
        copy_buffer(track_focus, src, dst)
      end
      render_splice()
    elseif x == 9 then
      track_focus = i
      arc_track_focus = track_focus
      view_buffer = z == 1 and true or false
      render_splice()
    elseif x == 10 and z == 1 then
      params:set(i.."buffer_sel", track[i].side == 0 and 2 or 1)
      if track_focus == i then
        render_splice()
      end
    elseif x == 11 then
      track_focus = i
      arc_track_focus = track_focus
      view_splice_info = z == 1 and true or false
      if z == 0 then
        render_splice()
      end
    elseif x == 12 and z == 1 then
      local input = params:get(i.."input_options")
      if input == 1 then
        params:set(i.."input_options", 3)
      elseif input == 2 then
        params:set(i.."input_options", 4)
      elseif input == 3 then
        params:set(i.."input_options", 1)
      elseif input == 4 then 
        params:set(i.."input_options", 2)
      end
    elseif x == 13 and z == 1 then
      local input = params:get(i.."input_options")
      if input == 1 then
        params:set(i.."input_options", 2)
      elseif input == 2 then
        params:set(i.."input_options", 1)
      elseif input == 3 then
        params:set(i.."input_options", 4)
      elseif input == 4 then 
        params:set(i.."input_options", 3)
      end
    elseif x == 14 and y < 7 then
      sends_focus = i
      view_track_send = z == 1 and true or false
      if z == 0 then
        render_splice()
      end
    elseif x == 15 and z == 1 then
      if y < 6 then
        route[i].t5 = 1 - route[i].t5
        local e = {} e.t = eROUTE e.i = i e.ch = 5 e.route = route[i].t5 event(e)
      end
    elseif x == 16 then
      if y < 7 and z == 1 then
        route[i].t6 = 1 - route[i].t6
        local e = {} e.t = eROUTE e.i = i e.ch = 6 e.route = route[i].t6 event(e)
      elseif y == 7 then
        view_presets = z == 1 and true or false
        if z == 0 then
          render_splice()
        end
      end
    end
  elseif y == 8 then
    grd_one.cutfocus_keys(x, z)
  end
  dirtyscreen = true
  dirtygrid = true
end

function grd_one.tape_draw()
  g:all(0)
  grd_one.drawnav()
  grd_one.cutfocus_draw()
  -- splice selection
  for i = 1, 8 do
    g:led(i, track_focus + 1, 2)
    for j = 1, 6 do
      if i == track[j].splice_active then
        g:led(i, j + 1, track[j].loaded and 12 or pulse_key_slow)
      elseif i == track[j].splice_focus then
        g:led(i, j + 1, 5)
      end
    end
  end
  -- buffer selection
  for i = 1, 6 do
    g:led(10, i + 1, track[i].side == 1 and 4 or 10)
  end
  -- input selection
  for i = 1, 6 do
    g:led(12, i + 1, (params:get(i.."input_options") == 1 or params:get(i.."input_options") == 2) and 8 or 4)
    g:led(13, i + 1, (params:get(i.."input_options") == 1 or params:get(i.."input_options") == 3) and 8 or 4)
  end
  -- routing
  for i = 1, 4 do
    local y = i + 1
    g:led(15, y, route[i].t5 == 1 and 9 or 2)
  end
  for i = 1, 5 do
    local y = i + 1
    g:led(16, y, route[i].t6 == 1 and 9 or 2)
  end
  g:led(16, 7, view_presets and 15 or 5)
  g:refresh()
end

return grd_one