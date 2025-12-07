package simulator

CellState :: enum u8 {
	Dead  = 0,
	Alive = 1,
}

Cell :: struct {
	state: CellState,
}
