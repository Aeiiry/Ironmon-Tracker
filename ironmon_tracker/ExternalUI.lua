-- Defines all ways to interact with an emulator's external UI components, such as form popups
ExternalUI = {}

-- Contains information related to Bizhawk forms (the popup windows)
ExternalUI.BizForms = {
	-- The current active form popup window; only 1 can be open at any given time
	ActiveFormId = 0,

	-- Options to modify form control elements; usually don't change these
	AUTO_SIZE_CONTROLS = true,

	-- Enum representing the different types of controls that can be created for a form
	ControlTypes = {
		Button = 1, Checkbox = 2, Dropdown = 3, Label = 4, TextBox = 5,
	},
	Properties = {
		AUTO_SIZE = "AutoSize", -- For most form elements
		BLOCK_INPUT = "BlocksInputWhenFocused", -- For the main form popup
		AUTO_COMPLETE_SOURCE = "AutoCompleteSource", -- For dropdown boxes
		AUTO_COMPLETE_MODE = "AutoCompleteMode", -- For dropdown boxes
		MAX_LENGTH = "MaxLength", -- For textboxes
		FORE_COLOR = "ForeColor", -- For most form elements
	},
}

function ExternalUI.initialize()
	ExternalUI.BizForms.ActiveFormId = 0
end

---Creates a form popup through Bizhawk Lua function
---@param title string?
---@param width number
---@param height number
---@param x number? Optional
---@param y number? Optional
---@param onCloseFunc function? Optional
---@param blockInput boolean? Optional, default is true
---@return IBizhawkForm form An IBizhawkForm object representing the created form
function ExternalUI.BizForms.createForm(title, width, height, x, y, onCloseFunc, blockInput)
	-- Close the active form popup that's currently open, if any (only one at a time allowed to be open)
	ExternalUI.BizForms.destroyForm()

	-- Prepare the form to be created, defining defaults
	local form = ExternalUI.IBizhawkForm:new({
		Title = title, Width = width, Height = height, X = x, Y = y,
		BlockInput = (blockInput ~= false),
		OnCloseFunc = onCloseFunc,
	})

	if not Main.IsOnBizhawk() then
		return form
	end

	local function safelyCloseForm()
		Input.resumeMouse = true
		client.unpause()
		if not form then
			return
		end
		if type(form.OnCloseFunc) == "function" then
			form:OnCloseFunc()
		end
		if ExternalUI.BizForms.ActiveFormId == form.ControlId then
			ExternalUI.BizForms.ActiveFormId = 0
		end
		form:destroy()
	end

	-- Disable mouse inputs on the emulator window until the form is closed
	Input.allowMouse = false
	Input.resumeMouse = false

	-- Create the form through Bizhawk
	form.ControlId = forms.newform(form.Width, form.Height, form.Title, safelyCloseForm)

	-- Remember this form, and apply any other adjustments like screen centering
	ExternalUI.BizForms.ActiveFormId = form.ControlId
	Utils.setFormLocation(form.ControlId, form.X, form.Y)

	-- A workaround for a bug for release candidate builds of Bizhawk 2.9
	if Main.emulator == Main.EMU.BIZHAWK29 or Main.emulator == Main.EMU.BIZHAWK_FUTURE then
		local currentPropVal = forms.getproperty(form.ControlId, ExternalUI.BizForms.Properties.BLOCK_INPUT)
		if not Utils.isNilOrEmpty(currentPropVal) then
			forms.setproperty(form.ControlId, ExternalUI.BizForms.Properties.BLOCK_INPUT, form.BlockInput)
		end
	end

	return form
end

---Safely closes and destroys a specific form, or the active open form popup if none provided
---@param formOrId IBizhawkForm|number|nil Optional
function ExternalUI.BizForms.destroyForm(formOrId)
	if not Main.IsOnBizhawk() then return end

	formOrId = formOrId or {}
	local controlId
	if type(formOrId) == "table" then
		controlId = formOrId.ControlId
	elseif type(formOrId) == "number" then
		controlId = formOrId
	end
	controlId = controlId or ExternalUI.BizForms.ActiveFormId

	Input.resumeMouse = true
	client.unpause()
	if (controlId or 0) ~= 0 then
		forms.destroy(controlId)
	end
	ExternalUI.BizForms.ActiveFormId = 0
end

---Pauses emulation and opens a standard openfile dialog prompt; returns the chosen filepath, or an empty string if cancelled
---@param filename string
---@param directory string Often uses/includes `FileManager.dir`
---@param filterOptions string Example: "Tracker Data (*.TDAT)|*.tdat|All files (*.*)|*.*"
---@return string filepath, boolean success
function ExternalUI.BizForms.openFilePrompt(filename, directory, filterOptions)
	local filepath = ""
	if not Main.IsOnBizhawk() then
		return filepath, false
	end
	-- Disable the sound, since the openfile dialog will cause their emulation to stutter
	Utils.tempDisableBizhawkSound()
	filepath = forms.openfile(filename, directory, filterOptions)
	Utils.tempEnableBizhawkSound()
	local success = not Utils.isNilOrEmpty(filepath)
	return filepath, success
end

---Gets the text caption for a given form Control element, usually from a textbox or dropdown
---@param controlId number
---@return string
function ExternalUI.BizForms.getText(controlId)
	if (controlId or 0) == 0 or not Main.IsOnBizhawk() then
		return ""
	end
	return forms.gettext(controlId) or ""
end

---Sets the text caption for a given form Control element, usually for a textbox or dropdown
---@param controlId number
---@param text string?
function ExternalUI.BizForms.setText(controlId, text)
	if (controlId or 0) == 0 or not Main.IsOnBizhawk() then
		return
	end
	forms.settext(controlId, text or "")
end

---Returns true if the Checkbox control is checked; false otherwise
---@param controlId number
---@return boolean
function ExternalUI.BizForms.isChecked(controlId)
	if (controlId or 0) == 0 or not Main.IsOnBizhawk() then
		return false
	end
	return forms.ischecked(controlId)
end

---Gets a string representation of the value of a property of a Control
---@param controlId number
---@param property string
---@return string
function ExternalUI.BizForms.getProperty(controlId, property)
	if (controlId or 0) == 0 or not property or not Main.IsOnBizhawk() then
		return ""
	end
	return forms.getproperty(controlId, property) or ""
end

---Attempts to set the given property of the widget with the given value.
---Note: not all properties will be able to be represented for the control to accept
---@param controlId number
---@param property string
---@param value any?
function ExternalUI.BizForms.setProperty(controlId, property, value)
	if (controlId or 0) == 0 or not property or not Main.IsOnBizhawk() then
		return
	end
	forms.setproperty(controlId, property, value or "")
end

--- HELPER FUNCTIONS
local _helper = {}
function _helper.tryAutoSize(controlId, width, height)
	if not Main.IsOnBizhawk() then return end
	if ExternalUI.BizForms.AUTO_SIZE_CONTROLS and not width and not height then
		forms.setproperty(controlId, ExternalUI.BizForms.Properties.AUTO_SIZE, true)
	end
end

--- BIZHAWK FORM OBJECT

--- An object representing a Bizhawk form popup. Contains useful Bizhawk Lua functions to create controls:
--- Button, Checkbox, Dropdown, Label, TextBox
---@class IBizhawkForm
ExternalUI.IBizhawkForm = {
	-- This value is set after the form is created; do not define it yourself
	ControlId = 0,
	-- Optional code to run when the form is closed
	OnCloseFunc = function() end,
	-- Table of created Bizhawk controls: key=id, val=ControlType
	CreatedControls = {},

	-- After the Bizhawk form itself is created, the following attributes cannot be changed
	Title = "Tracker Form",
	X = 100,
	Y = 50,
	Width = 600,
	Height = 600,
	BlockInput = true, -- Disable mouse inputs on the emulator window until the form is closed

	destroy = function(self)
		ExternalUI.BizForms.destroyForm(self)
	end,
}
---Creates and returns a new IBizhawkForm object; use `createBizhawkForm` to create a form popup instead of calling this directly
---@param o? table Optional initial object table
---@return table form An IBizhawkForm object
function ExternalUI.IBizhawkForm:new(o)
	o = o or {}
	for k, v in pairs(ExternalUI.IBizhawkForm) do
		if o[k] == nil then
			o[k] = v
		end
	end
	setmetatable(o, self)
	self.__index = self
	return o
end

---Creates a Button Control element for a Bizhawk form, returning the id of the created control
---@param text string
---@param clickFunc function
---@param x number
---@param y number
---@param width number? Optional
---@param height number? Optional
---@return number controlId
function ExternalUI.IBizhawkForm:createButton(text, x, y, clickFunc, width, height)
	if not Main.IsOnBizhawk() then return 0 end
	local controlId = forms.button(self.ControlId, text, clickFunc, x, y, width, height)
	_helper.tryAutoSize(controlId, width, height)
	self.CreatedControls[controlId] = ExternalUI.BizForms.ControlTypes.Button
	return controlId
end

---Creates a Checkbox Control element for a Bizhawk form, returning the id of the created control
---@param text string
---@param x number
---@param y number
---@param clickFunc function? Optional, note that you usually don't need a click func for this
---@return number controlId
function ExternalUI.IBizhawkForm:createCheckbox(text, x, y, clickFunc)
	if not Main.IsOnBizhawk() then return 0 end
	local controlId = forms.checkbox(self.ControlId, text, x, y)
	_helper.tryAutoSize(controlId)
	if type(clickFunc) == "function" then
		forms.addclick(controlId, clickFunc)
	end
	self.CreatedControls[controlId] = ExternalUI.BizForms.ControlTypes.Checkbox
	return controlId
end

---Creates a Dropdown Control element for a Bizhawk form, returning the id of the created control
---@param itemList table An ordered list of values (ideally strings)
---@param x number
---@param y number
---@param width number?
---@param height number?
---@param startItem string?
---@param sortAlphabetically boolean? Optional, default is true
---@param clickFunc function? Optional, note that you usually don't need a click func for this
---@return number controlId
function ExternalUI.IBizhawkForm:createDropdown(itemList, x, y, width, height, startItem, sortAlphabetically, clickFunc)
	if not Main.IsOnBizhawk() then return 0 end
	sortAlphabetically = (sortAlphabetically ~= false) -- default to true
	local controlId = forms.dropdown(self.ControlId, {["Init"]="..."}, x, y, width, height)
	forms.setdropdownitems(controlId, itemList, sortAlphabetically)
	forms.setproperty(controlId, ExternalUI.BizForms.Properties.AUTO_COMPLETE_SOURCE, "ListItems")
	forms.setproperty(controlId, ExternalUI.BizForms.Properties.AUTO_COMPLETE_MODE, "Append")
	if startItem then
		forms.settext(controlId, startItem)
	end
	_helper.tryAutoSize(controlId, width, height)
	if type(clickFunc) == "function" then
		forms.addclick(controlId, clickFunc)
	end
	self.CreatedControls[controlId] = ExternalUI.BizForms.ControlTypes.Dropdown
	return controlId
end

---Creates a Label Control element for a Bizhawk form, returning the id of the created control
---@param text string
---@param x number
---@param y number
---@param width number?
---@param height number?
---@param monospaced boolean? Optional, if true will use a a monospaced font: Courier New (size 8)
---@param clickFunc function? Optional, note that you usually don't need a click func for this
---@return number controlId
function ExternalUI.IBizhawkForm:createLabel(text, x, y, width, height, monospaced, clickFunc)
	if not Main.IsOnBizhawk() then return 0 end
	monospaced = (monospaced == true) -- default to false
	local controlId = forms.label(self.ControlId, text, x, y, width, height, monospaced)
	_helper.tryAutoSize(controlId, width, height)
	if type(clickFunc) == "function" then
		forms.addclick(controlId, clickFunc)
	end
	self.CreatedControls[controlId] = ExternalUI.BizForms.ControlTypes.Label
	return controlId
end

---Creates a TextBox Control element for a Bizhawk form, returning the id of the created control
---@param text string
---@param x number
---@param y number
---@param width number?
---@param height number?
---@param boxtype string? Optional, restricts the textbox input; available options: HEX, SIGNED, UNSIGNED
---@param multiline boolean? Optional, if true will enable the standard winform multi-line property
---@param monospaced boolean? Optional, if true will use a a monospaced font: Courier New (size 8)
---@param scrollbars string? Optional when using multiline; available options: Vertical, Horizontal, Both, None
---@param clickFunc function? Optional, note that you usually don't need a click func for this
---@return number controlId
function ExternalUI.IBizhawkForm:createTextBox(text, x, y, width, height, boxtype, multiline, monospaced, scrollbars, clickFunc)
	if not Main.IsOnBizhawk() then return 0 end
	multiline = (multiline == true) -- default to false
	monospaced = (monospaced == true) -- default to false
	local controlId = forms.textbox(self.ControlId, text, width, height, boxtype, x, y, multiline, monospaced, scrollbars)
	_helper.tryAutoSize(controlId, width, height)
	if type(clickFunc) == "function" then
		forms.addclick(controlId, clickFunc)
	end
	self.CreatedControls[controlId] = ExternalUI.BizForms.ControlTypes.TextBox
	return controlId
end
