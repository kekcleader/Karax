(* Copyright 2018 Arthur Yefimov, Daniel Vysotsky, Patrik Alexandryan

This file is part of Karax.

Karax is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Free Oberon is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Foobar.  If not, see <http://www.gnu.org/licenses/>.
*)
MODULE Karax;
IMPORT Out, G := Graph;
CONST
  maxW = 32; maxH = 32;   (* Максимальные размеры карты *)
  cellW = 32; cellH = 32; (* Размеры одной клетки *)
  tilesPerLine = 4;
  firstUnit = 8;

TYPE
  Cell = RECORD
    type: INTEGER; (* Тип клетки *)
    team: INTEGER  (* За кого играет эта единица: 0/1 *)
  END;

VAR
  s: G.Bitmap; (* Экран *)
  tiles: G.Bitmap; (* Изображения всех возможных клеток *)
  mouse, hand: G.Bitmap; (* Указатели мыши *)
  map: ARRAY maxH, maxW OF Cell; (* Карта *)
  W, H: INTEGER; (* Актуальные размеры карты *)
  mapX, mapY: INTEGER; (* Смещение карты на экране *)
  needFlip: BOOLEAN;
  
  drag: RECORD
    on: BOOLEAN; (* Происходит ли сейчас перетаскивание *)
    out: BOOLEAN; (* Находится ли мышь за пределами области перетаскивания *)
    unitX, unitY: INTEGER; (* За какую клетку на карте схватились *)
    innerX, innerY: INTEGER; (* За какое место клетки схватилась мышь *)
    x, y: INTEGER; (* Где находится перетаскиваемое на экране *)
    x1, y1, x2, y2: INTEGER (* Разрешённая область перетаскивания *)
  END;

PROCEDURE GenerateMap;
VAR x, y: INTEGER;
BEGIN
  W := 18; H := 12;
  (* Основа *)
  FOR y := 0 TO H - 1 DO
    FOR x := 0 TO W - 1 DO
      map[y, x].type := 1;
    END
  END;
  (* Вода *)
  FOR y := H DIV 2 - 1 TO H DIV 2 DO
    FOR x := 0 TO W - 1 DO map[y, x].type := 2 END;
    FOR x := 2 TO W - 3 BY 2 DO map[y, x].type := 1 END
  END;
  (* Единицы *)
  FOR x := 0 TO W - 1 DO
    FOR y := 0 TO 2 DO
      map[y, x].type := G.Random(2) + 8;
      map[y, x].team := 1
    END;
    FOR y := H - 3 TO H - 1 DO
      map[y, x].type := G.Random(2) + 8;
      map[y, x].team := 0
    END
  END
END GenerateMap;

PROCEDURE Init;
BEGIN
  GenerateMap;
  mapX := (s.w - cellW * W) DIV 2;
  mapY := (s.h - cellH * H) DIV 2
END Init;

(* Рисует клетку карты (x; y) на экране в точке (dx, dy) *)
PROCEDURE DrawCell(x, y, dx, dy: INTEGER);
VAR
  t: INTEGER; (* Тип клетки *)
  sx, sy: INTEGER; (* Смещение рисунка клетки в tiles *)
  clr: INTEGER;
BEGIN
  t := map[y, x].type;
  sx := t MOD tilesPerLine * cellW;
  sy := t DIV tilesPerLine * cellH;
  IF t >= firstUnit THEN
    (* Подложка клетки (только для единиц) *)
    G.Blit(tiles, s, 0, 0, cellW, cellH, dx, dy);
  END;
  (* Изображение единицы *)
  G.Blit(tiles, s, sx, sy, cellW, cellH, dx, dy);
  (* Цвет команды *)
  IF t >= firstUnit THEN
    IF map[y, x].team = 0 THEN clr := G.MakeCol(230, 0, 0)
    ELSE clr := G.MakeCol(0, 128, 255)
    END;
    G.RectFill(s, dx + 1, dy + 1, dx + 3, dy + 3, clr)
  END
END DrawCell;

PROCEDURE DrawMap;
VAR x, y, dx, dy: INTEGER;
BEGIN
  FOR y := 0 TO H - 1 DO
    FOR x := 0 TO W - 1 DO
      dx := mapX + x * cellW;
      dy := mapY + y * cellH;
      DrawCell(x, y, dx, dy)
    END
  END
END DrawMap;

PROCEDURE DrawDrag;
VAR dx, dy: INTEGER;
BEGIN
  (* Перекрытие оригинальной клетки *)
  dx := mapX + drag.unitX * cellW;
  dy := mapY + drag.unitY * cellH;
  G.Blit(tiles, s, cellW, 0, cellW, cellH, dx, dy);
  (* Перетаскиваемая (плавающая) клетка *)
  dx := drag.x - drag.innerX;
  dy := drag.y - drag.innerY;
  DrawCell(drag.unitX, drag.unitY, dx, dy)
END DrawDrag;

PROCEDURE Act;
BEGIN
  G.ClearScreen;
  DrawMap;
  IF drag.on THEN DrawDrag END;
  IF needFlip THEN G.Flip END
END Act;

PROCEDURE IsDraggable(x, y: INTEGER): BOOLEAN;
BEGIN
  RETURN (map[y, x].type >= firstUnit) & (map[y, x].team = 0)
END IsDraggable;

PROCEDURE IsDroppable(x, y: INTEGER): BOOLEAN;
BEGIN
  RETURN map[y, x].type = 1
END IsDroppable;

PROCEDURE Drop(x, y: INTEGER);
BEGIN
  map[y, x].type := map[drag.unitY, drag.unitX].type;
  map[drag.unitY, drag.unitX].type := 1
END Drop;

PROCEDURE WrapXY(VAR x, y: INTEGER; x1, y1, x2, y2: INTEGER);
BEGIN
  IF x < x1 THEN x := x1 ELSIF x > x2 THEN x := x2 END;
  IF y < y1 THEN y := y1 ELSIF y > y2 THEN y := y2 END
END WrapXY;

PROCEDURE DragMove;
VAR x, y: INTEGER;
BEGIN
  G.GetMousePos(x, y);
  drag.out := (x < drag.x1) OR (x > drag.x2) OR
    (y < drag.y1) OR (y > drag.y2);
  WrapXY(x, y, drag.x1 + drag.innerX, drag.y1 + drag.innerY,
    drag.x2 + drag.innerX - cellW, drag.y2 + drag.innerY - cellH);
  drag.x := x; drag.y := y
END DragMove;

PROCEDURE OnMouseDown(VAR e: G.Event);
VAR x, y: INTEGER;
BEGIN
  x := (e.x - mapX) DIV cellW;
  y := (e.y - mapY) DIV cellH;
  IF (x >= 0) & (x < W) & (y >= 0) & (y < H) THEN
    IF IsDraggable(x, y) THEN
      drag.on := TRUE;
      drag.unitX := x;
      drag.unitY := y;
      drag.innerX := (e.x - mapX) MOD cellW;
      drag.innerY := (e.y - mapY) MOD cellH;
      drag.x1 := mapX + (x - 2) * cellW;
      drag.x2 := drag.x1 + 5 * cellW;
      drag.y1 := mapY + (y - 2) * cellH;
      drag.y2 := drag.y1 + 5 * cellH;
      DragMove;
      G.SetMousePointer(hand, 6, 4)
    END
  END
END OnMouseDown;

PROCEDURE OnMouseUp(VAR e: G.Event);
VAR x, y: INTEGER;
BEGIN
  IF drag.on THEN
    drag.on := FALSE;
    G.SetMousePointer(mouse, 0, 0);
    x := (drag.x - mapX) DIV cellW;
    y := (drag.y - mapY) DIV cellH;
    IF (x >= 0) & (x < W) & (y >= 0) & (y < H) &
       ((drag.unitX # x) OR (drag.unitY # y)) &
       IsDroppable(x, y) & ~drag.out THEN
      Drop(x, y)
    END
  END
END OnMouseUp;

PROCEDURE OnMouseMove(VAR e: G.Event);
BEGIN
  IF drag.on THEN DragMove END
END OnMouseMove;

PROCEDURE Run;
VAR quit: BOOLEAN;
  e: G.Event;
BEGIN
  needFlip := TRUE; quit := FALSE;
  drag.on := FALSE;
  REPEAT
    G.WaitEvents(50);
    WHILE G.PollEvent(e) DO
      CASE e.type OF
        G.quit: quit := TRUE
      | G.keyDown: IF e.key.code = G.kEsc THEN quit := TRUE END
      | G.mouseDown: OnMouseDown(e)
      | G.mouseUp: OnMouseUp(e)
      | G.mouseMove: OnMouseMove(e); needFlip := TRUE
      ELSE
      END
    END;
    Act
  UNTIL quit
END Run;

BEGIN
  G.Settings(640, 400, {G.fullscreen, G.spread, G.sharpPixels, G.initMouse});
  s := G.Init();
  IF s = NIL THEN Out.String('Could not init graph.'); Out.Ln
  ELSE
    tiles := G.LoadBitmap('data/graph/tiles.png');
    IF tiles = NIL THEN Out.String('Could not load tiles.'); Out.Ln
    ELSE
      mouse := G.LoadBitmap('data/graph/mouse.png');
      IF mouse # NIL THEN G.SetMousePointer(mouse, 0, 0) END;
      hand := G.LoadBitmap('data/graph/hand.png');
      Init;
      G.ClearScreen;
      Run;
      G.Close
    END
  END
END Karax.
