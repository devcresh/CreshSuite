local _, CC = ...

-- CreshChat Chess piece texture manifest
-- WoW TBC-ready 64x64 uncompressed TGA textures with alpha.
_G.CreshChatChessTextures = {
    White = {
        King = "Interface\\AddOns\\CreshChat\\Media\\Games\\Chess\\White\\King_White.tga",
        Queen = "Interface\\AddOns\\CreshChat\\Media\\Games\\Chess\\White\\Queen_White.tga",
        Rook = "Interface\\AddOns\\CreshChat\\Media\\Games\\Chess\\White\\Rook_White.tga",
        Bishop = "Interface\\AddOns\\CreshChat\\Media\\Games\\Chess\\White\\Bishop_White.tga",
        Knight = "Interface\\AddOns\\CreshChat\\Media\\Games\\Chess\\White\\Knight_White.tga",
        Pawn = "Interface\\AddOns\\CreshChat\\Media\\Games\\Chess\\White\\Pawn_White.tga",
    },
    Black = {
        King = "Interface\\AddOns\\CreshChat\\Media\\Games\\Chess\\Black\\King_Black.tga",
        Queen = "Interface\\AddOns\\CreshChat\\Media\\Games\\Chess\\Black\\Queen_Black.tga",
        Rook = "Interface\\AddOns\\CreshChat\\Media\\Games\\Chess\\Black\\Rook_Black.tga",
        Bishop = "Interface\\AddOns\\CreshChat\\Media\\Games\\Chess\\Black\\Bishop_Black.tga",
        Knight = "Interface\\AddOns\\CreshChat\\Media\\Games\\Chess\\Black\\Knight_Black.tga",
        Pawn = "Interface\\AddOns\\CreshChat\\Media\\Games\\Chess\\Black\\Pawn_Black.tga",
    },
    Notation = {
        WK = "Interface\\AddOns\\CreshChat\\Media\\Games\\Chess\\White\\King_White.tga",
        BK = "Interface\\AddOns\\CreshChat\\Media\\Games\\Chess\\Black\\King_Black.tga",
        WQ = "Interface\\AddOns\\CreshChat\\Media\\Games\\Chess\\White\\Queen_White.tga",
        BQ = "Interface\\AddOns\\CreshChat\\Media\\Games\\Chess\\Black\\Queen_Black.tga",
        WR = "Interface\\AddOns\\CreshChat\\Media\\Games\\Chess\\White\\Rook_White.tga",
        BR = "Interface\\AddOns\\CreshChat\\Media\\Games\\Chess\\Black\\Rook_Black.tga",
        WB = "Interface\\AddOns\\CreshChat\\Media\\Games\\Chess\\White\\Bishop_White.tga",
        BB = "Interface\\AddOns\\CreshChat\\Media\\Games\\Chess\\Black\\Bishop_Black.tga",
        WN = "Interface\\AddOns\\CreshChat\\Media\\Games\\Chess\\White\\Knight_White.tga",
        BN = "Interface\\AddOns\\CreshChat\\Media\\Games\\Chess\\Black\\Knight_Black.tga",
        WP = "Interface\\AddOns\\CreshChat\\Media\\Games\\Chess\\White\\Pawn_White.tga",
        BP = "Interface\\AddOns\\CreshChat\\Media\\Games\\Chess\\Black\\Pawn_Black.tga",
    }
}

-- Example: texture:SetTexture(CreshChatChessTextures.White.King)
if CC then
    CC.Assets = CC.Assets or {}
    CC.Assets.Chess = _G.CreshChatChessTextures
    if CC.RegisterModule then CC:RegisterModule("ChessAssets", { version = CC.version, library = _G.CreshChatChessTextures }) end
end
