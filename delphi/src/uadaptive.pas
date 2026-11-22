{ uAdaptive - Personalized Menus, new in 2000.

  The File, Features and View menus show only the items you use. The rest
  wait behind "Show all items" at the bottom, which shows them all. Use an
  item and it stays in the short menu from then on (for this run: nothing is
  written anywhere). Keyboard shortcuts of hidden items don't work, because
  Windows takes a hidden item's shortcut with it. That is how it was, and it
  is why people turned this off. }
unit uAdaptive;

{$mode objfpc}{$H+}

interface

const
  MORE_TAG = 'More';

{ Should the item with this command key be in the menu right now? }
function AdaptiveShows(const ATag: string): Boolean;
{ A menu item was used: it joins the short menu, and the menus go short again. }
procedure AdaptiveUsed(const ATag: string);
procedure AdaptiveExpand;
function AdaptiveExpanded: Boolean;

implementation

const
  // what the short menus show before you've used anything
  SHOWN_AT_FIRST = '|New|Open|Save|Exit|Extrude|Hole|Fillet|Chamfer|ViewIso|ZoomFit|Regen|Shaded|';

var
  mUsed: string;            // "|Tag|" for each item used this run
  mExpanded: Boolean;       // "Show all items" was chosen and nothing since

function AdaptiveShows(const ATag: string): Boolean;
begin
  if mExpanded then Exit(True);
  Result := Pos('|' + ATag + '|', SHOWN_AT_FIRST + mUsed) > 0;
end;

procedure AdaptiveUsed(const ATag: string);
begin
  if (ATag = MORE_TAG) or (ATag = '') then Exit;
  if Pos('|' + ATag + '|', SHOWN_AT_FIRST + mUsed) = 0 then mUsed := mUsed + '|' + ATag + '|';
  mExpanded := False;
end;

procedure AdaptiveExpand;
begin
  mExpanded := True;
end;

function AdaptiveExpanded: Boolean;
begin
  Result := mExpanded;
end;

end.
