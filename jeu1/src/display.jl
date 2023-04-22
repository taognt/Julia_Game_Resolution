using JuMP
using CPLEX
using Gtk


#resolution
include("resolution_flip.jl")

#window
win = Gtk.Window("Grid Game")
grid = Gtk.Grid()

for i in 1:3
    for j in 1:3
        btn = Gtk.Button()
        btn.override_background_color(:normal, ifelse(mod(i+j,2)==0, "black", "white"))
        Gtk.Widget.set_size_request(btn, 100, 100)
        grid.attach(btn, i, j, 1, 1)
    end
end

push!(win, grid)
showall(win)



