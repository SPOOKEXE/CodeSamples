# Code Samples for Scripter (Star)

All code is gathered from
https://www.roblox.com/games/9775652302/RPG-Series-ALPHA

The full YouTube stream playlist for the creation of this game from the ground up can be found at
https://www.youtube.com/playlist?list=PLbgTkBDB9V7Rb7mNXWfQw_OsP6W75U8P3

3D noise line thingie 
https://gyazo.com/8c2ac07c5716bfb516eb390a44471796
```lua
-- sampel code for above gyazo

-- get pos0, pos1
local Pos0 = self.Pos0
local Pos1 = self.Pos1
local direction = (self.Pos1+self.Pos0).Unit
local distance = (self.Pos1-self.Pos0).Magnitude
local noiseConfig = self.Noise

-- create offsetted points
table.insert(self.Vec3Points, Pos0)
local deltaStep = self.TotalPoints == 1 and 0.5 or (1 / self.TotalPoints)
for i = 1, self.TotalPoints do
    local delta = (i * deltaStep)
    local pos = Pos0:Lerp(Pos1, delta)
    
    --local x = math.sin(i + self.Noise.Position.X) * 3
    --local y = math.cos(i + self.Noise.Position.Z) * 3
    --local z = (delta/distance)
    
    --local noiseOffset = Vector3.new( direction.X * x, direction.Y * y, direction.Z * z )
    
    local noiseOffset = get3DNoise( noiseConfig.Seed, pos + noiseConfig.Position, noiseConfig.MapScale, noiseConfig.Amplitude )
    --print(i, noiseOffset)
    table.insert(self.Vec3Points, pos + noiseOffset)
end
```

Vector Fields
https://gyazo.com/e71269190a373fc52f5f2e4dfa19be05
https://gyazo.com/65f1d45c60fa3d99c19b326fd0bb35ec

QuadTree Rendering
https://gyazo.com/c7ba5ece6c401d811206636440abc63a

Particle System (using a QuadTree for collision)
https://gyazo.com/a1cb08c98ed41ab7afa29e71134c75c1
https://gyazo.com/ff4109aa6259ed1f52c6d3d59ee5f03a

Circuitry Fun
https://gyazo.com/c4532452026b403acd42405920f27d03

A* Pathfinding Map Generator + Solver
https://gyazo.com/b8dd12fff37d509958b7accd44fdfcdc

Crystal Storm Ability
https://gyazo.com/77df0288744a7716553a9ab80a087176

Simple Heal Ability
https://gyazo.com/dcca2485e60d918658bd450122b2d2d4

Simulator Stuff
https://gyazo.com/a590831abc55d54e2107f625c47e753a

That one simulator system (click to attack enemy)
https://gyazo.com/f0b50f8bf37287676b8ac8ec8e3040bf

Anime Fighters sytem
https://gyazo.com/4c666a00c3358c8a33220cda86769479

Gun Bullet Stress Test (part of a framework that is WIP)
https://gyazo.com/ef2b0abdc1c0c2a01b19cfad89e0f27c



