Event = require('opus.event')
UI    = require('opus.ui')

kernel     = _G.kernel
multishell = _ENV.multishell
tasks      = multishell and multishell.getTabs and multishell.getTabs() or kernel.routines

UI\configure 'Tasks', ...

page = UI.Page {
	menuBar: UI.MenuBar {
		buttons: {
			{ text: 'Activate',  event: 'activate'  },
			{ text: 'Terminate', event: 'terminate' },
			{ text: 'Inspect',   event: 'inspect'   },
		},
	},
	grid: UI.ScrollingGrid {
		y: 2,
		columns: {
			{ heading: 'ID',     key: 'uid',      width: 3 },
			{ heading: 'Title',  key: 'title'     },
			{ heading: 'Status', key: 'status'    },
			{ heading: 'Time',   key: 'timestamp' },
		},
		values: tasks,
		sortColumn: 'uid',
		autospace: true,
		getDisplayValues: (row) =>
			elapsed = os.clock! - row.timestamp
			{
				uid: row.uid,
				title: row.title,
				status: row.isDead and 'error' or coroutine.status(row.co),
				timestamp: elapsed < 60 and
					string.format("%ds", math.floor(elapsed)) or
					string.format("%sm", math.floor(elapsed/6)/10),
			}
	},
	accelerators: {
		[ 'control-q' ]: 'quit',
		[ ' ' ]: 'activate',
		t: 'terminate',
	},
	eventHandler: (event) =>
		t = self.grid\getSelected!
		switch event.type
			when 'activate', 'grid_select'
				multishell.setFocus t.uid if t
			when 'terminate'
				multishell.terminate t.uid if t
			when 'inspect'
				multishell.openTab _ENV, {
					path: 'sys/apps/Lua.lua',
					args: { t },
					focused: true,
				} if t
			when 'quit'
				UI\quit!
			else
				UI.Page.eventHandler(@, event)
}

Event.onInterval 1, () ->
	page.grid\update!
	page.grid\draw!
	page\sync!

UI\setPage page
UI\start!
