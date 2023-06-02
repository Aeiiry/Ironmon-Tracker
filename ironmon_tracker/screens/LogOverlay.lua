LogOverlay = {
	Colors = {
		headerText = "Header text",
		headerBorder = "Upper box background",
		headerFill = "Main background",
	},
	margin = 2,
	tabHeight = 12,
	isDisplayed = false,
	isGameOver = false, -- Set to true when game is over, so we known to show game over screen if X is pressed
}

-- Dimensions of the screen space occupied by the currentl visible Tab
LogOverlay.TabBox = {
	x = LogOverlay.margin,
	y = LogOverlay.tabHeight,
	width = Constants.SCREEN.WIDTH - (LogOverlay.margin * 2),
	height = Constants.SCREEN.HEIGHT - LogOverlay.tabHeight - LogOverlay.margin - 1,
}

-- A stack manage the back-button within tabs, each element is { tab, page, }
LogOverlay.TabHistory = {}

LogOverlay.Windower = {
	currentTab = nil,
	currentPage = nil,
	totalPages = nil,
	infoId = -1,
	filterGrid = "#",
	getPageText = function(self)
		if self.totalPages == nil or self.totalPages < 1 then return Resources.AllScreens.Page end
		return string.format("%s %s/%s", Resources.AllScreens.Page, self.currentPage, self.totalPages)
	end,
	prevPage = function(self)
		if self.totalPages == nil or self.totalPages <= 1 then return end
		self.currentPage = ((self.currentPage - 2 + self.totalPages) % self.totalPages) + 1
		Program.redraw(true)
	end,
	nextPage = function(self)
		if self.totalPages == nil or self.totalPages <= 1 then return end
		self.currentPage = (self.currentPage % self.totalPages) + 1
		Program.redraw(true)
	end,
	changeTab = function(self, newTab, pageNum, totalPages, tabInfoId, filterGrid)
		if newTab == nil then return end
		if not LogOverlay.isDisplayed then
			LogOverlay.isDisplayed = true
		end

		local prevTab = {
			tab = self.currentTab,
			page = self.currentPage,
			totalPages = self.totalPages,
			infoId = self.infoId,
			filterGrid = self.filterGrid,
		}

		self.currentTab = newTab
		self.currentPage = pageNum or self.currentPage or 1
		self.totalPages = totalPages or self.totalPages or 1
		self.infoId = tabInfoId or self.infoId or -1
		self.filterGrid = filterGrid or self.filterGrid or "#"

		if newTab == LogTabPokemonDetails then
			LogTabPokemonDetails.buildZoomButtons(self.infoId)
			if prevTab.tab ~= LogTabPokemonDetails then
				table.insert(LogOverlay.TabHistory, prevTab)
			end
		elseif newTab == LogTabTrainerDetails then
			LogTabTrainerDetails.buildZoomButtons(self.infoId)
			if prevTab.tab ~= LogTabPokemonDetails and prevTab.tab ~= LogTabTrainerDetails then
				table.insert(LogOverlay.TabHistory, prevTab)
			end
		elseif newTab == LogTabRouteDetails then
			LogTabRouteDetails.buildZoomButtons(self.infoId)
			LogTabRouteDetails.realignGrid(filterGrid, nil, pageNum)
			if prevTab.tab ~= LogTabPokemonDetails and prevTab.tab ~= LogTabTrainerDetails then
				table.insert(LogOverlay.TabHistory, prevTab)
			end
		end

		LogOverlay.refreshButtons()

		-- After reloading the search results content, update to show the last viewed page and grid
		if LogSearchScreen.tryDisplayOrHide() then
			self.currentPage = pageNum or self.currentPage or 1
			self.totalPages = totalPages or self.totalPages or 1
			self.infoId = tabInfoId or self.infoId or -1
			self.filterGrid = filterGrid or self.filterGrid or "#"
		end
	end,
	goBack = function(self)
		local prevTab = table.remove(LogOverlay.TabHistory)
		if prevTab ~= nil then
			self:changeTab(prevTab.tab, prevTab.page, prevTab.totalPages, prevTab.infoId, prevTab.filterGrid)
		else
			LogTabPokemon.realignGrid()
			self:changeTab(LogTabPokemon)
		end
	end,
}

local pagerOffsetX = 155
LogOverlay.HeaderButtons = {
	CurrentPage = {
		type = Constants.ButtonTypes.NO_BORDER,
		getText = function(self) return LogOverlay.Windower:getPageText() end,
		textColor = LogOverlay.Colors.headerText,
		box = { LogOverlay.margin + pagerOffsetX, 0, 50, 10, },
		isVisible = function() return LogOverlay.Windower.totalPages > 1 end, -- Likely won't use, unsure where to place it
	},
	PrevPage = {
		type = Constants.ButtonTypes.PIXELIMAGE,
		image = Constants.PixelImages.LEFT_ARROW,
		textColor = LogOverlay.Colors.headerText,
		shadowcolor = false,
		box = { LogOverlay.margin + pagerOffsetX - 13, 1, 10, 10 },
		isVisible = function() return LogOverlay.Windower.totalPages > 1 end,
		onClick = function(self) LogOverlay.Windower:prevPage() end,
	},
	NextPage = {
		type = Constants.ButtonTypes.PIXELIMAGE,
		image = Constants.PixelImages.RIGHT_ARROW,
		textColor = LogOverlay.Colors.headerText,
		shadowcolor = false,
		box = { LogOverlay.margin + pagerOffsetX + 50, 1, 10, 10 },
		isVisible = function() return LogOverlay.Windower.totalPages > 1 end,
		onClick = function(self) LogOverlay.Windower:nextPage() end,
	},
	XIcon = {
		type = Constants.ButtonTypes.PIXELIMAGE,
		image = Constants.PixelImages.CLOSE,
		textColor = LogOverlay.Colors.headerText,
		box = { LogOverlay.margin + 228, 2, 10, 10 },
		updateSelf = function(self)
			local canGoBackTabs = {
				[LogTabPokemonDetails] = true,
				[LogTabTrainerDetails] = true,
				[LogTabRouteDetails] = true,
			}
			if canGoBackTabs[LogOverlay.Windower.currentTab] then
				self.textColor = Theme.headerHighlightKey
				self.image = Constants.PixelImages.LEFT_ARROW
				self.box[2] = 1
			else
				self.textColor = LogOverlay.Colors.headerText
				self.image = Constants.PixelImages.CLOSE
				self.box[2] = 2
			end
		end,
		onClick = function(self)
			if self.image == Constants.PixelImages.CLOSE then
				LogOverlay.TabHistory = {}
				LogOverlay.isDisplayed = false
				LogSearchScreen.clearSearch()
				if LogOverlay.isGameOver then
					Program.changeScreenView(GameOverScreen)
				elseif not Program.isValidMapLocation() then
					-- If the game hasn't started yet
					Program.changeScreenView(StartupScreen)
				else
					Program.changeScreenView(TrackerScreen)
				end
			else -- Constants.PixelImages.PREVIOUS_BUTTON
				LogOverlay.Windower:goBack()
				Program.redraw(true)
			end
		end,
	},
}

-- Navigation filters for each of the window tabs. Each has a label for the button, and a sort function for the grid
LogOverlay.NavFilters = {
	Trainers = {
		All = {
			getText = function() return Resources.LogOverlay.FilterAll end,
			group = TrainerData.TrainerGroups.All,
			index = 1,
			sortFunc = function(a, b)
				if a.group < b.group then
					return true
				elseif a.group == b.group then
					if a.group == TrainerData.TrainerGroups.Rival or a.group == TrainerData.TrainerGroups.Boss then
						return (a.maxlevel or 999) < (b.maxlevel or 999)
					elseif a.group == TrainerData.TrainerGroups.Gym or a.group == TrainerData.TrainerGroups.Elite4 then
						return (a.maxlevel or 999) < (b.maxlevel or 999)
					elseif a.id < b.id then
						return true
					end
				end
				return false
			end,
		},
		Rival = {
			getText = function() return Resources.LogOverlay.FilterRival end,
			group = TrainerData.TrainerGroups.Rival,
			index = 2,
			sortFunc = function(a, b) return a.maxlevel < b.maxlevel end,
		},
		Gym = {
			getText = function() return Resources.LogOverlay.FilterGym end,
			group = TrainerData.TrainerGroups.Gym,
			index = 3,
			sortFunc = function(a, b) return a.image:sub(-5) < b.image:sub(-5) end,
		},
		Elite4 = {
			getText = function() return Resources.LogOverlay.FilterElite4 end,
			group = TrainerData.TrainerGroups.Elite4,
			index = 4,
			sortFunc = function(a, b) return a.image:sub(-5) < b.image:sub(-5) end,
		},
		Boss = {
			getText = function() return Resources.LogOverlay.FilterBoss end,
			group = TrainerData.TrainerGroups.Boss,
			index = 5,
			sortFunc = function(a, b) return a.maxlevel < b.maxlevel end,
		},
		-- { -- Temp Removing both of these until better data gets sorted out
		-- 	getText = function() return Resources.LogOverlay.FilterOther end,
		-- 	group = TrainerData.TrainerGroups.Other,
		-- 	sortFunc = function(a, b) return a:getText() < b:getText() end,
		-- },
		-- {
		-- 	getText = function() return "(?)" end,
		-- 	group = "?",
		-- },
	},
	TMs = {
		TMNumber = { -- If this changes from index 2, update it's references
			getText = function() return Resources.LogOverlay.FilterTMNumber end,
			group = "TM #",
			index = 10,
			sortFunc = function(a, b) return a.tmNumber < b.tmNumber end,
		},
		GymTMs = { -- If this changes from index 2, update it's references
			getText = function() return Resources.LogOverlay.FilterGymTMs end,
			group = "Gym TMs",
			index = 11,
			sortFunc = function(a, b) return a.gymNumber < b.gymNumber end,
		},
	},
}

function LogOverlay.initialize()
	LogOverlay.isDisplayed = false
	LogOverlay.isGameOver = false

	LogOverlay.TabHistory = {}
	LogOverlay.Windower.currentTab = nil

	LogOverlay.addHeaderTabButtons()

	for _, button in pairs(LogOverlay.HeaderButtons) do
		if button.textColor == nil then
			button.textColor = LogOverlay.Colors.headerText
		end
		if button.boxColors == nil then
			button.boxColors = { LogOverlay.Colors.headerBorder, LogOverlay.Colors.headerFill }
		end
	end

	if Options["Open Book Play Mode"] then
		local logpath = LogOverlay.getLogFileAutodetected() or LogOverlay.getLogFileFromPrompt()

		if not Utils.isNilOrEmpty(logpath) then
			RandomizerLog.loadedLogPath = logpath
			local success = RandomizerLog.parseLog(logpath)

			if success then
				LogOverlay.buildAllTabs()
				LogOverlay.Windower.currentTab = LogTabPokemon
				LogSearchScreen.resetSearchSortFilter()
				LogOverlay.refreshActiveTabGrid()
			end
		end
	end
end

function LogOverlay.refreshButtons()
	for _, button in pairs(LogOverlay.HeaderButtons) do
		if type(button.updateSelf) == "function" then
			button:updateSelf()
		end
	end
end

function LogOverlay.addHeaderTabButtons()
	local orderedTabs = {
		LogTabPokemon,
		LogTabTrainers,
		LogTabRoutes,
		LogTabTMs,
		LogTabMisc,
	}
	local offsetX = LogOverlay.margin + 1
	local spacer = 3

	for i, tab in ipairs(orderedTabs) do
		local icons = tab.getTabIcons()
		tab.chosenIcon = icons[1]
		local width = spacer
		for _, icon in ipairs(icons or {}) do
			width = width + (icon.w or 0) + spacer
		end
		local tabButton = {
	LogOverlay.Buttons.CurrentPage:updateText()
	LogOverlay.Buttons.PreEvoSettingButton.toggleState = Options["Show Pre Evolutions"]
end

-- Builds out paged-buttons that are shown on the log viewer overlay based on the parse data
function LogOverlay.buildPagedButtons()
	LogOverlay.PagedButtons = {}

	local navStartX, navStartY = 4, LogOverlay.tabHeight + 1 -- Alternative, at the bottom: Constants.SCREEN.HEIGHT - LogOverlay.margin - 13

	-- Build Pokemon buttons
	LogOverlay.PagedButtons.Pokemon = {}
	for id = 1, PokemonData.totalPokemon, 1 do
		if RandomizerLog.Data.Pokemon[id] ~= nil then
			local button = {
				type = Constants.ButtonTypes.POKEMON_ICON,
				pokemonID = id,
				pokemonName = PokemonData.Pokemon[id].name,
				tab = LogOverlay.Tabs.POKEMON,
				textColor = "Default text",
				boxColors = { "Upper box border", "Upper box background" },
				isVisible = function(self)
					return LogOverlay.currentTab == self.tab and LogOverlay.Windower.currentPage == self.pageVisible
				end,
				includeInGrid = function(self)
					local include = false

					if LogOverlay.Windower.filterGrid == "#" then
						include = true
						-- Pokemon name
					elseif LogSearchScreen.currentFilter == Constants.Words.POKEMON .. " Name" then
						include = LogOverlay.Windower.filterGrid:lower() ==
							self.pokemonName:sub(1, #LogOverlay.Windower.filterGrid):lower() or

							-- Check whole word for matches, not just the start
							(self.pokemonName:lower():find(LogOverlay.Windower.filterGrid:lower()))
						-- Ability name
					elseif LogSearchScreen.currentFilter == "Ability" then
						for _, ability in pairs(RandomizerLog.Data.Pokemon[id].Abilities) do
							local abilityText = AbilityData.Abilities[ability].name
							if LogOverlay.Windower.filterGrid:lower() ==
								abilityText:sub(1, #LogOverlay.Windower.filterGrid):lower() or

								-- Check whole word for matches, not just the start
								(abilityText:lower():find(LogOverlay.Windower.filterGrid:lower())) then
								include = true
								break
							end
						end
						-- Learnable moves
					elseif LogSearchScreen.currentFilter == "Levelup Move" then
						for _, move in pairs(RandomizerLog.Data.Pokemon[id].MoveSet) do
								local moveText = move.name
								if LogOverlay.Windower.filterGrid:lower() ==
									moveText:sub(1, #LogOverlay.Windower.filterGrid):lower() or

									-- Check whole word for matches, not just the start
									(moveText:lower():find(LogOverlay.Windower.filterGrid:lower())) then
									include = true
									break
								end
						end
					end
					return include
				end,
				getIconPath = function(self)
					local iconset = Options.IconSetMap[Options["Pokemon icon set"]]
					return FileManager.buildImagePath(iconset.folder, tostring(self.pokemonID), iconset.extension)
				end,
				onClick = function(self)
					LogOverlay.Windower:changeTab(LogOverlay.Tabs.POKEMON_ZOOM, 1, 1, self.pokemonID)
					InfoScreen.changeScreenView(InfoScreen.Screens.POKEMON_INFO, self.pokemonID) -- implied redraw
				end,
				draw = function(self, shadowcolor)
					local pokemonName = PokemonData.Pokemon[self.pokemonID].name
					local labelBox = {
						x = self.box[1] + self.box[3] / 2 - Utils.calcWordPixelLength(pokemonName) / 2 - 3,
						y = self.box[2] + 28,
						width = Utils.calcWordPixelLength(pokemonName) + 3,
						height = 12,
					}
					--shadow
					gui.drawRectangle(labelBox.x +1, labelBox.y +1, labelBox.width, labelBox.height, shadowcolor, shadowcolor)

					--border
					gui.drawRectangle(labelBox.x, labelBox.y, labelBox.width, labelBox.height, Theme.COLORS[self.boxColors[1]], Theme.COLORS[self.boxColors[1]])
					--background
					gui.drawRectangle(labelBox.x + 1, labelBox.y + 1, labelBox.width - 2, labelBox.height - 2,
						Theme.COLORS[self.boxColors[2]], Theme.COLORS[self.boxColors[2]])
					--center text
					Drawing.drawText(labelBox.x , labelBox.y, pokemonName, Theme.COLORS[self.textColor], shadowcolor)
				end,
			}
			table.insert(LogOverlay.PagedButtons.Pokemon, button)
		end
	end
local navOffsetX = navStartX
--[[ 	-- Build Pokemon navigation

	local navLabels = { "#", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "(?)", }
	for _, navLabel in ipairs(navLabels) do
		local labelWidth = Utils.calcWordPixelLength(navLabel) + 2 -- +2 to make it a bit wider
		local jumpBtn = {
			type = Constants.ButtonTypes.NO_BORDER,
			text = navLabel,
			textColor = "Default text",
			tab = LogOverlay.Tabs.POKEMON,
			box = { LogOverlay.margin + navOffsetX, navStartY, labelWidth, 11 },
			isVisible = function(self) return LogOverlay.currentTab == self.tab end,
			updateText = function(self)
				if LogOverlay.Windower.filterGrid == self.text then
					self.textColor = "Intermediate text"
				else
					self.textColor = "Default text"
				end
			end,
			draw = function(self)
				-- Draw an underline if selected
				if self.textColor == "Intermediate text" then
					local x1, x2 = self.box[1] + 2, self.box[1] + self.box[3] + 1
					local y1, y2 = self.box[2] + self.box[4] - 1, self.box[2] + self.box[4] - 1
					gui.drawLine(x1, y1, x2, y2, Theme.COLORS[self.textColor])
				end
			end,
			onClick = function(self)
				if self.text == "(?)" then
					local pokemonId = Utils.randomPokemonID()
					LogOverlay.Windower:changeTab(LogOverlay.Tabs.POKEMON_ZOOM, 1, 1, pokemonId)
					InfoScreen.changeScreenView(InfoScreen.Screens.POKEMON_INFO, pokemonId) -- implied redraw
					return
				end

				local sortFunc
				if self.text == "#" then
					sortFunc = function(a, b) return a.pokemonID < b.pokemonID end
				else
					sortFunc = function(a, b) return a.pokemonName < b.pokemonName end
				end
				LogOverlay.realignPokemonGrid(self.text, sortFunc)
				LogOverlay.refreshInnerButtons()
				Program.redraw(true)
			end,
		}
		table.insert(LogOverlay.Buttons, jumpBtn)
		navOffsetX = navOffsetX + labelWidth + 1
		if navLabel == "#" then
			navOffsetX = navOffsetX + 8
		elseif navLabel == "Z" then
			navOffsetX = navOffsetX + 8
		end
	end]]

	-- Determine gym TMs for the game, they'll be highlighted
	local gymTMs = {}
	for i, gymTM in ipairs(TrainerData.GymTMs) do
		gymTMs[gymTM.number] = {
			leader = gymTM.leader,
			gymNumber = i,
			trainerId = nil, -- this gets added in later
		}
	end

	-- Build Trainer buttons
	LogOverlay.PagedButtons.Trainers = {}
	for id, trainerData in pairs(RandomizerLog.Data.Trainers) do
		local trainerInfo = TrainerData.getTrainerInfo(id)
		-- TODO: Implement actual name laters when full trainer list is ready
		-- local customName = Utils.inlineIf(trainerInfo.name ~= "Unknown", trainerInfo.name, trainerData.name)
		local customName = trainerInfo.name
		local fileInfo = TrainerData.FileInfo[trainerInfo.filename] or { width = 40, height = 40 }
		local button = {
			type = Constants.ButtonTypes.IMAGE,
			image = FileManager.buildImagePath(FileManager.Folders.Trainers, trainerInfo.filename, FileManager.Extensions.TRAINER),
			text = customName,
			trainerId = id,
			filename = trainerInfo.filename, -- helpful for sorting later
			dimensions = { width = fileInfo.width, height = fileInfo.height, extraX = fileInfo.offsetX, extraY = fileInfo.offsetY, },
			group = trainerInfo.group,
			tab = LogOverlay.Tabs.TRAINER,
			isVisible = function(self) return LogOverlay.currentTab == self.tab and LogOverlay.Windower.currentPage == self.pageVisible end,
			includeInGrid = function(self)
				local shouldInclude = LogOverlay.Windower.filterGrid == TrainerData.TrainerGroups.All or LogOverlay.Windower.filterGrid == self.group
				local shouldExclude = trainerInfo.name == "Unknown"
				-- Exclude extra rivals
				if trainerInfo.whichRival ~= nil and Tracker.Data.whichRival ~= nil and Tracker.Data.whichRival ~= trainerInfo.whichRival then
					shouldExclude = true
				end
				return shouldInclude and not shouldExclude
			end,
			onClick = function(self)
				LogOverlay.Windower:changeTab(LogOverlay.Tabs.TRAINER_ZOOM, 1, 1, self.trainerId)
				Program.redraw(true)
				-- InfoScreen.changeScreenView(InfoScreen.Screens.TRAINER_INFO, self.trainerId) -- TODO: (future feature) implied redraw
			end,
		}

		if trainerInfo ~= nil and trainerInfo.group == TrainerData.TrainerGroups.Gym then
			local gymNumber = tonumber(trainerInfo.filename:sub(-1)) -- e.g. "frlg-gymleader-1"
			if gymNumber ~= nil then
				-- Find the gym leader's TM and add it's trainer id to that tm info
				for _, gymTMInfo in pairs(gymTMs) do
					if gymTMInfo.gymNumber == gymNumber then
						gymTMInfo.trainerId = id
						break
					end
				end
			end
		end

		table.insert(LogOverlay.PagedButtons.Trainers, button)
	end

	-- Build Trainer navigation
	navOffsetX = navStartX + 40
	for _, navLabel in ipairs(LogOverlay.NavFilters.Trainers) do
		local labelWidth = Utils.calcWordPixelLength(navLabel.label) + 4
		local jumpBtn = {
			type = Constants.ButtonTypes.NO_BORDER,
			-- getText = function(self) return Resources.LogOverlay[tabScreen.TitleResourceKey or ""] end,
			icons = icons or {},
			index = i,
			isSelected = false,
			box = { offsetX, 0, width, 11, },
			updateSelf = function(self)
				self.isSelected = (LogOverlay.Windower.currentTab == tab)
				self.textColor = Utils.inlineIf(self.isSelected, Theme.headerHighlightKey, LogOverlay.Colors.headerText)
			end,
			draw = function(self, shadowcolor)
				local x, y = self.box[1], self.box[2]
				for _, icon in ipairs(self.icons) do
					if icon.image then
						local adjustedX = x + (icon.x or 0) + spacer
						local adjustedY = y + (icon.y or 0) + LogOverlay.tabHeight - (icon.h or 12)
						Drawing.drawImage(icon.image, adjustedX, adjustedY)
						x = x + (icon.w or 0) + spacer
					end
					local prefferredCategory = ""
					local atkSpaDiff = data.p.atk / data.p.spa
					if atkSpaDiff > 1.5 then
						prefferredCategory = "Physical"
					elseif atkSpaDiff < 0.66 then
						prefferredCategory = "Special"
					end
					if prefferredCategory == "Physical" and MoveData.Moves[self.moveId].category == MoveData.Categories.PHYSICAL then
						Drawing.drawChevron(self.box[1] + moveCategoryOffset + 8, self.box[2]-1, 2, 1, 1, "up",Theme.COLORS["Positive text"])
					elseif prefferredCategory == "Special" and MoveData.Moves[self.moveId].category == MoveData.Categories.SPECIAL then
						Drawing.drawChevron(self.box[1] + moveCategoryOffset + 8, self.box[2]-1, 2, 1, 1, "up", Theme.COLORS["Positive text"])
					end
				end
				-- if self.isSelected then
				-- 	Drawing.drawUnderline(self, Theme.COLORS[self.textColor])
				-- end
			end,
			onClick = function(self)
				if self.isSelected then return end -- Don't change if already on this tab
				LogOverlay.TabHistory = {}
				LogOverlay.Windower:changeTab(tab)
				LogSearchScreen.resetSearchSortFilter()
				LogOverlay.refreshActiveTabGrid()
				Program.redraw(true)
			end,
		}
		LogOverlay.HeaderButtons[tab] = tabButton
		offsetX = offsetX + width + spacer
	end
end

-- Build out all paged buttons for all Tab screens using the parsed data
function LogOverlay.buildAllTabs()
	-- Pokemon
	LogTabPokemon.buildPagedButtons()
	-- Trainers
	local gymTMs = LogTabTrainers.buildPagedButtons()
	-- Routes
	LogTabRoutes.buildPagedButtons()
	-- TMs
	LogTabTMs.buildPagedButtons(gymTMs)
end

function LogOverlay.refreshActiveTabGrid()
	local currentTab = LogOverlay.Windower.currentTab or {}
	if type(currentTab.realignGrid) == "function" then
		if not Utils.isNilOrEmpty(LogSearchScreen.searchText) and LogSearchScreen.AllowedTabViews[currentTab] then
			currentTab.realignGrid(LogOverlay.Windower.filterGrid, LogSearchScreen.currentSortOrder.sortFunc)
		else
			currentTab.realignGrid()
		end
	elseif type(currentTab.refreshButtons) == "function" then
		LogOverlay.Windower.filterGrid = ""
		LogOverlay.Windower.totalPages = 1
		LogOverlay.Windower.currentPage = 1
		currentTab.refreshButtons()
	end
end

-- Rebuilds the buttons for the currently displayed screen. Useful when the Tracker's display language changes
function LogOverlay.rebuildScreen()
	if not LogOverlay.isDisplayed then return end

	-- Rebuild majority of the data, and clear out navigation history
	LogOverlay.TabHistory = {}
	LogOverlay.buildAllTabs()

	local currentTab = LogOverlay.Windower.currentTab or {}
	if type(currentTab.rebuild) == "function" then
		currentTab.rebuild()
	end

	LogOverlay.refreshButtons()
end

function LogOverlay.getPlayerIconHead()
	local seedChoice = (Main.currentSeed or 1) % 2
	local trainerHeadIcons = {
		[1] = { [0] = "girl-rs", [1] = "boy-rs", }, -- Ruby/Sapphire
		[2] = { [0] = "girl-e", [1] = "boy-e", }, -- Emerald
		[3] = { [0] = "girl-frlg", [1] = "boy-frlg", }, -- FireRed/LeafGreen
	}
	local trainerHead = trainerHeadIcons[GameSettings.game][seedChoice]
	return FileManager.buildImagePath("player", trainerHead, FileManager.Extensions.TRAINER)
end

-- USER INPUT FUNCTIONS
function LogOverlay.checkInput(xmouse, ymouse)
	if not LogOverlay.isDisplayed then return end

	Input.checkButtonsClicked(xmouse, ymouse, LogOverlay.HeaderButtons)

	local currentTab = LogOverlay.Windower.currentTab or {}
	if type(currentTab.checkInput) == "function" then
		currentTab.checkInput(xmouse, ymouse)
	end
end

-- DRAWING FUNCTIONS
function LogOverlay.drawScreen()
	if not LogOverlay.isDisplayed then return end

	Drawing.drawBackgroundAndMargins(0, 0, Constants.SCREEN.WIDTH, Constants.SCREEN.HEIGHT)

	local currentTab = LogOverlay.Windower.currentTab or {}

	local headerShadow = Utils.calcShadowColor(Theme.COLORS["Main background"])
	local borderColor = Theme.COLORS["Upper box border"]
	if currentTab.Colors and currentTab.Colors.border then
		borderColor = Theme.COLORS[currentTab.Colors.border]
	end

	-- Draw tab dividers; color depends on currently viewed tab
	gui.drawLine(LogOverlay.margin, 1, LogOverlay.margin, LogOverlay.TabBox.y - 1, borderColor)
	local dividerHeight = LogOverlay.tabHeight - 1
	for _, headerTab in ipairs(Utils.getSortedList(LogOverlay.HeaderButtons)) do
		local rightEdge = headerTab.box[1] + headerTab.box[3] + 2
		gui.drawLine(rightEdge, LogOverlay.tabHeight - dividerHeight, rightEdge, LogOverlay.TabBox.y, borderColor)
	end

	-- Draw all buttons
	for _, button in pairs(LogOverlay.HeaderButtons) do
		Drawing.drawButton(button, headerShadow)
	end

	-- Draw current tab
	if type(currentTab.drawTab) == "function" then
		currentTab.drawTab()
	end
end

function LogOverlay.viewLogFile(postfix)
	local logpath = LogOverlay.getLogFileAutodetected(postfix)

	-- Check if there exists a parsed log with the same postfix as the one being requested
	local hasParsedThisLog = RandomizerLog.Data.Settings ~= nil and string.find(RandomizerLog.loadedLogPath or "", postfix, 1, true) ~= nil

	-- Only prompt for a new file if no autodetect and nothing has been parsed yet
	if logpath == nil and not hasParsedThisLog then
		logpath = LogOverlay.getLogFileFromPrompt()
	end

	LogOverlay.parseAndDisplay(logpath)
end

--- Attempts to determine the log file that matches the currently loaded rom. If not match or can't find, returns nil
--- @param postFix string? The file's postFix, most likely FileManager.PostFixes.AUTORANDOMIZED or FileManager.PostFixes.PREVIOUSATTEMPT
--- @return string?
function LogOverlay.getLogFileAutodetected(postFix)
	postFix = postFix or FileManager.PostFixes.AUTORANDOMIZED

	local romname, rompath
	if Options["Use premade ROMs"] and Options.FILES["ROMs Folder"] ~= nil then
		-- First make sure the ROMs Folder ends with a slash
		if Options.FILES["ROMs Folder"]:sub(-1) ~= FileManager.slash then
			Options.FILES["ROMs Folder"] = Options.FILES["ROMs Folder"] .. FileManager.slash
		end

		romname = GameSettings.getRomName() or ""
		if postFix == FileManager.PostFixes.PREVIOUSATTEMPT then
			local currentRomPrefix = string.match(romname, '[^0-9]+') or ""
			local currentRomNumber = string.match(romname, '[0-9]+') or "0"
			-- Decrement to the previous ROM and determine its full file path
			local prevRomName = string.format(currentRomPrefix .. "%0" .. string.len(currentRomNumber) .. "d", tonumber(currentRomNumber) - 1)
			romname = prevRomName
		end

		rompath = Options.FILES["ROMs Folder"] .. romname .. FileManager.Extensions.GBA_ROM
		if not FileManager.fileExists(rompath) then
			romname = romname:gsub(" ", "_")
			rompath = Options.FILES["ROMs Folder"] .. romname .. FileManager.Extensions.GBA_ROM
		end
	elseif Options["Generate ROM each time"] then
		-- Filename of the AutoRandomized ROM is based on the settings file (for cases of playing Kaizo + Survival + Others)
		local quickloadFiles = Main.GetQuickloadFiles()
		local settingsFileName = FileManager.extractFileNameFromPath(quickloadFiles.settingsList[1] or "")
		romname = string.format("%s %s%s", settingsFileName, postFix, FileManager.Extensions.GBA_ROM)
		rompath = FileManager.prependDir(romname)
	end

	-- Check if the name of the rom being played on the emulator matches the name of the autodetected rom
	if Main.IsOnBizhawk() then
		local plainFormatter = function(filename)
			-- strip out any auto appended postfixes
			filename = filename:gsub(FileManager.PostFixes.AUTORANDOMIZED, "")
			filename = filename:gsub(FileManager.PostFixes.PREVIOUSATTEMPT, "")
			filename = filename:gsub("%.gba", "")
			filename = filename:gsub(" ", "_")
			filename = filename:gsub("%d", "")
			return filename:lower()
		end
		local loadedRomName = GameSettings.getRomName() or "N/A"
		loadedRomName = plainFormatter(loadedRomName .. FileManager.Extensions.GBA_ROM)
		local autodetectedName = plainFormatter(romname or "")
		if loadedRomName ~= autodetectedName then
			return nil
		end
	end

	-- Return the full file path of the log file, or nil if it can't be found
	return FileManager.getPathIfExists((rompath or "") .. FileManager.Extensions.RANDOMIZER_LOGFILE)
end

--- Prompts user to select a log file to parse
--- @return string?
function LogOverlay.getLogFileFromPrompt()
	local suggestedFileName = (GameSettings.getRomName() or "") .. FileManager.Extensions.RANDOMIZER_LOGFILE
	local filterOptions = "Randomizer Log (*.log)|*.log|All files (*.*)|*.*"

	local workingDir = FileManager.dir
	if not Utils.isNilOrEmpty(workingDir) then
		workingDir = workingDir:sub(1, -2) -- remove trailing slash
	end

	Utils.tempDisableBizhawkSound()
	local filepath = forms.openfile(suggestedFileName, workingDir, filterOptions)
	if Utils.isNilOrEmpty(filepath) then
		filepath = nil
	end
	Utils.tempEnableBizhawkSound()

	return filepath
end

function LogOverlay.parseAndDisplay(logpath)
	-- Check for what log we're trying to display, and if it's already been parsed
	if logpath ~= nil and RandomizerLog.loadedLogPath ~= logpath then
		RandomizerLog.Data = {}
		RandomizerLog.loadedLogPath = logpath
	end

	-- If data has already been loaded and parsed, use that first, otherwise try parsing the provided log file
	if RandomizerLog.Data.Settings ~= nil then
		LogOverlay.isDisplayed = true
	else
		LogOverlay.isDisplayed = RandomizerLog.parseLog(logpath)
	end

	if LogOverlay.isDisplayed then
		LogOverlay.TabHistory = {}
		LogOverlay.buildAllTabs()
		LogOverlay.Windower:changeTab(LogTabPokemon)
		LogSearchScreen.resetSearchSortFilter()
		LogOverlay.refreshActiveTabGrid()
		-- If the player has a Pokemon, show it on the side-screen
		local leadPokemon = Tracker.getPokemon(1, true) or {}
		if PokemonData.isValid(leadPokemon.pokemonID) then
			LogOverlay.Windower:changeTab(LogTabPokemonDetails, 1, 1, leadPokemon.pokemonID)
			InfoScreen.changeScreenView(InfoScreen.Screens.POKEMON_INFO, leadPokemon.pokemonID)
		else
			Program.redraw(true)
		end
	end

	return LogOverlay.isDisplayed
end
