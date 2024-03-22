package sources

import (
	"os"
	"strconv"
	"time"
)

// The timeout duration for the API engine_forkchoiceUpdated
var forkChoiceUpdateTimeout = 5 * time.Second

func init() {
	value, _ := strconv.Atoi(os.Getenv("FORK_CHOICE_UPDATE_TIMEOUT"))
	if value > 0 {
		forkChoiceUpdateTimeout = time.Duration(value) * time.Second
	}
}
