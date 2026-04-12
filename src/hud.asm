; ============================================================
; hud.asm - Hud with Scr at top and Vit at bottom
; Game over blinking (visible 30 frames, hidden 30 frames)
; You Escaped blinking (visible 30 frames, hidden 30 frames)
; ============================================================

.export update_score_hud
.export draw_hud

; --- Import zero page variables from main.asm ---
.importzp player_score, player_hp
.importzp hud_score_hundreds, hud_score_tens, hud_score_units
.importzp gameover_blink_timer, temp, temp2
.importzp game_won

HUD_Y_SCR = $D7
HUD_Y_VIT = $DF
HUD_ATTR  = %00000011
HUD_HIDE  = $FF

; YOU:     tile X=14 → px=$70, tile Y=27 → px=$D8
; ESCAPED: tile X=12 → px=$60, tile Y=28 → px=$E0
YOU_Y     = $D8
YOU_X     = $70
ESC_Y     = $E0
ESC_X     = $60

; ============================================================
; Update score hud
; ============================================================
.proc update_score_hud
  LDA player_score
  STA temp
  LDA player_score+1
  STA temp2

  LDA #$00
  STA hud_score_hundreds
@h_loop:
  LDA temp2
  BNE @h_sub
  LDA temp
  CMP #100
  BCC @h_done
@h_sub:
  LDA temp
  SEC
  SBC #100
  STA temp
  LDA temp2
  SBC #$00
  STA temp2
  INC hud_score_hundreds
  JMP @h_loop
@h_done:

  LDA #$00
  STA hud_score_tens
@t_loop:
  LDA temp
  CMP #10
  BCC @t_done
  SEC
  SBC #10
  STA temp
  INC hud_score_tens
  JMP @t_loop
@t_done:

  LDA temp
  STA hud_score_units
  RTS
.endproc

; ============================================================
; Draw hud
; ============================================================
.proc draw_hud
  ; Update blink timer (shared by game over and you escaped)
  INC gameover_blink_timer
  LDA gameover_blink_timer
  CMP #60
  BCC @check_state
  LDA #$00
  STA gameover_blink_timer
@check_state:

  ; --- Check win first ---
  LDA game_won
  BEQ @not_won
  JMP @show_you_escaped
@not_won:

  ; --- Then check game over ---
  LDA player_hp
  BNE @show_normal_hud
  JMP @show_gameover

@show_normal_hud:
  ; ==========================================
  ; Top row (Y=$D7): Scr: 000
  ; ==========================================

  ; S
  LDA #HUD_Y_SCR
  STA $0240
  LDA #$79
  STA $0241
  LDA #HUD_ATTR
  STA $0242
  LDA #$10
  STA $0243

  ; C
  LDA #HUD_Y_SCR
  STA $0244
  LDA #$7A
  STA $0245
  LDA #HUD_ATTR
  STA $0246
  LDA #$18
  STA $0247

  ; R
  LDA #HUD_Y_SCR
  STA $0248
  LDA #$7B
  STA $0249
  LDA #HUD_ATTR
  STA $024A
  LDA #$20
  STA $024B

  ; :
  LDA #HUD_Y_SCR
  STA $024C
  LDA #$7C
  STA $024D
  LDA #HUD_ATTR
  STA $024E
  LDA #$28
  STA $024F

  ; Space
  LDA #HUD_HIDE
  STA $0250
  LDA #$00
  STA $0251
  STA $0252
  LDA #$30
  STA $0253

  ; Hundreds
  LDA #HUD_Y_SCR
  STA $0254
  LDA hud_score_hundreds
  CLC
  ADC #$80
  STA $0255
  LDA #HUD_ATTR
  STA $0256
  LDA #$38
  STA $0257

  ; Tens
  LDA #HUD_Y_SCR
  STA $0258
  LDA hud_score_tens
  CLC
  ADC #$80
  STA $0259
  LDA #HUD_ATTR
  STA $025A
  LDA #$40
  STA $025B

  ; Units
  LDA #HUD_Y_SCR
  STA $025C
  LDA hud_score_units
  CLC
  ADC #$80
  STA $025D
  LDA #HUD_ATTR
  STA $025E
  LDA #$48
  STA $025F

  ; ==========================================
  ; Bottom row (Y=$DF): Vit: ❤❤❤
  ; ==========================================

  ; V
  LDA #HUD_Y_VIT
  STA $0260
  LDA #$8B
  STA $0261
  LDA #HUD_ATTR
  STA $0262
  LDA #$10
  STA $0263

  ; I
  LDA #HUD_Y_VIT
  STA $0264
  LDA #$7D
  STA $0265
  LDA #HUD_ATTR
  STA $0266
  LDA #$18
  STA $0267

  ; T
  LDA #HUD_Y_VIT
  STA $0268
  LDA #$7E
  STA $0269
  LDA #HUD_ATTR
  STA $026A
  LDA #$20
  STA $026B

  ; :
  LDA #HUD_Y_VIT
  STA $026C
  LDA #$7C
  STA $026D
  LDA #HUD_ATTR
  STA $026E
  LDA #$28
  STA $026F

  ; Space
  LDA #HUD_HIDE
  STA $0270
  LDA #$00
  STA $0271
  STA $0272
  LDA #$30
  STA $0273

  ; Heart 1
  LDA player_hp
  CMP #1
  BCS @heart1_on
  LDA #HUD_HIDE
  STA $0274
  JMP @heart1_done
@heart1_on:
  LDA #HUD_Y_VIT
  STA $0274
@heart1_done:
  LDA #$7F
  STA $0275
  LDA #HUD_ATTR
  STA $0276
  LDA #$38
  STA $0277

  ; Heart 2
  LDA player_hp
  CMP #2
  BCS @heart2_on
  LDA #HUD_HIDE
  STA $0278
  JMP @heart2_done
@heart2_on:
  LDA #HUD_Y_VIT
  STA $0278
@heart2_done:
  LDA #$7F
  STA $0279
  LDA #HUD_ATTR
  STA $027A
  LDA #$40
  STA $027B

  ; Heart 3
  LDA player_hp
  CMP #3
  BCS @heart3_on
  LDA #HUD_HIDE
  STA $027C
  JMP @heart3_done
@heart3_on:
  LDA #HUD_Y_VIT
  STA $027C
@heart3_done:
  LDA #$7F
  STA $027D
  LDA #HUD_ATTR
  STA $027E
  LDA #$48
  STA $027F

  ; Hide game over sprites
  LDA #HUD_HIDE
  STA $0280
  STA $0284
  STA $0288
  STA $028C
  STA $0290
  STA $0294
  STA $0298
  STA $029C

  ; Hide you escaped sprites
  STA $02A0
  STA $02A4
  STA $02A8
  STA $02AC
  STA $02B0
  STA $02B4
  STA $02B8
  STA $02BC
  STA $02C0
  STA $02C4
  JMP @hud_done

  ; ==========================================
  ; Game over (blinking)
  ; ==========================================
@show_gameover:
  ; Hide Scr
  LDA #HUD_HIDE
  STA $0240
  STA $0244
  STA $0248
  STA $024C
  STA $0250
  STA $0254
  STA $0258
  STA $025C

  ; Hide Vit and hearts
  STA $0260
  STA $0264
  STA $0268
  STA $026C
  STA $0270
  STA $0274
  STA $0278
  STA $027C

  ; Hide you escaped sprites
  STA $02A0
  STA $02A4
  STA $02A8
  STA $02AC
  STA $02B0
  STA $02B4
  STA $02B8
  STA $02BC
  STA $02C0
  STA $02C4

  ; Check whether to show or not (blinking)
  LDA gameover_blink_timer
  CMP #30
  BCC @show_gameover_sprites
  ; Hide game over
  LDA #HUD_HIDE
  STA $0280
  STA $0284
  STA $0288
  STA $028C
  STA $0290
  STA $0294
  STA $0298
  STA $029C
  JMP @hud_done

@show_gameover_sprites:
  ; G
  LDA #$D7
  STA $0280
  LDA #$8C
  STA $0281
  LDA #HUD_ATTR
  STA $0282
  LDA #$70
  STA $0283

  ; A
  LDA #$D7
  STA $0284
  LDA #$8D
  STA $0285
  LDA #HUD_ATTR
  STA $0286
  LDA #$78
  STA $0287

  ; M
  LDA #$D7
  STA $0288
  LDA #$8E
  STA $0289
  LDA #HUD_ATTR
  STA $028A
  LDA #$80
  STA $028B

  ; E
  LDA #$D7
  STA $028C
  LDA #$8F
  STA $028D
  LDA #HUD_ATTR
  STA $028E
  LDA #$88
  STA $028F

  ; O
  LDA #$DF
  STA $0290
  LDA #$80
  STA $0291
  LDA #HUD_ATTR
  STA $0292
  LDA #$70
  STA $0293

  ; V
  LDA #$DF
  STA $0294
  LDA #$8B
  STA $0295
  LDA #HUD_ATTR
  STA $0296
  LDA #$78
  STA $0297

  ; E
  LDA #$DF
  STA $0298
  LDA #$8F
  STA $0299
  LDA #HUD_ATTR
  STA $029A
  LDA #$80
  STA $029B

  ; R
  LDA #$DF
  STA $029C
  LDA #$7B
  STA $029D
  LDA #HUD_ATTR
  STA $029E
  LDA #$88
  STA $029F
  JMP @hud_done

  ; ==========================================
  ; You Escaped (blinking)
  ; YOU     at X=$70 Y=$D8  (tile 14,27)
  ; ESCAPED at X=$60 Y=$E0  (tile 12,28)
  ; ==========================================
@show_you_escaped:
  ; Hide Scr, Vit, hearts and game over sprites
  LDA #HUD_HIDE
  STA $0240
  STA $0244
  STA $0248
  STA $024C
  STA $0250
  STA $0254
  STA $0258
  STA $025C
  STA $0260
  STA $0264
  STA $0268
  STA $026C
  STA $0270
  STA $0274
  STA $0278
  STA $027C
  STA $0280
  STA $0284
  STA $0288
  STA $028C
  STA $0290
  STA $0294
  STA $0298
  STA $029C

  ; Check blink (30 visible / 30 hidden)
  LDA gameover_blink_timer
  CMP #30
  BCC @show_you_escaped_sprites
  ; Hide you escaped
  LDA #HUD_HIDE
  STA $02A0
  STA $02A4
  STA $02A8
  STA $02AC
  STA $02B0
  STA $02B4
  STA $02B8
  STA $02BC
  STA $02C0
  STA $02C4
  JMP @hud_done

@show_you_escaped_sprites:
  ; --- YOU ($A0, $80, $A1) at Y=$D8, X starts at $70 ---

  ; Y
  LDA #YOU_Y
  STA $02A0
  LDA #$A0
  STA $02A1
  LDA #HUD_ATTR
  STA $02A2
  LDA #YOU_X
  STA $02A3

  ; O
  LDA #YOU_Y
  STA $02A4
  LDA #$80
  STA $02A5
  LDA #HUD_ATTR
  STA $02A6
  LDA #YOU_X + $08
  STA $02A7

  ; U
  LDA #YOU_Y
  STA $02A8
  LDA #$A1
  STA $02A9
  LDA #HUD_ATTR
  STA $02AA
  LDA #YOU_X + $10
  STA $02AB

  ; --- ESCAPED ($8F,$79,$7A,$8D,$A2,$8F,$A3) at Y=$E0, X starts at $60 ---

  ; E
  LDA #ESC_Y
  STA $02AC
  LDA #$8F
  STA $02AD
  LDA #HUD_ATTR
  STA $02AE
  LDA #ESC_X
  STA $02AF

  ; S
  LDA #ESC_Y
  STA $02B0
  LDA #$79
  STA $02B1
  LDA #HUD_ATTR
  STA $02B2
  LDA #ESC_X + $08
  STA $02B3

  ; C
  LDA #ESC_Y
  STA $02B4
  LDA #$7A
  STA $02B5
  LDA #HUD_ATTR
  STA $02B6
  LDA #ESC_X + $10
  STA $02B7

  ; A
  LDA #ESC_Y
  STA $02B8
  LDA #$8D
  STA $02B9
  LDA #HUD_ATTR
  STA $02BA
  LDA #ESC_X + $18
  STA $02BB

  ; P
  LDA #ESC_Y
  STA $02BC
  LDA #$A2
  STA $02BD
  LDA #HUD_ATTR
  STA $02BE
  LDA #ESC_X + $20
  STA $02BF

  ; E
  LDA #ESC_Y
  STA $02C0
  LDA #$8F
  STA $02C1
  LDA #HUD_ATTR
  STA $02C2
  LDA #ESC_X + $28
  STA $02C3

  ; D
  LDA #ESC_Y
  STA $02C4
  LDA #$A3
  STA $02C5
  LDA #HUD_ATTR
  STA $02C6
  LDA #ESC_X + $30
  STA $02C7

@hud_done:
  RTS
.endproc