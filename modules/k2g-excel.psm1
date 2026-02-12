#
#
# Kus-to-go Excel handler library
#
# Written by:
# - James Immer
# - Func documentation by Copilot
#
#

#
# Class to hold the workbook/sheet objects as well as a cell pointer
# used for easier navigation and sheet/workbook management
class ExcelWorkspace {

    [System.__ComObject]$workbook
    [System.__ComObject]$sheet
    [int]$pointerX
    [int]$pointerY

    # Bindings for ::new
    ExcelWorkspace([System.__ComObject]$workbook, [System.__ComObject]$sheet) {
        $this.workbook = $workbook
        $this.sheet = $sheet
        $this.pointerX = 1
        $this.pointerY = 1
    }

    # Moves the pointer one column to the right.
    [void] AdvanceX() { $this.pointerX += 1 }

    # Moves the pointer down one row and resets X.
    [void] AdvanceY() { $this.pointerY += 1; $this.pointerX = 0 }

    # Moves the pointer down one row without resetting X.
    [void] AdvanceYNoResetX() { $this.pointerY += 1 }

    # Saves the excel workbook to the provided path
    [void] SaveAs([string]$path) { $this.workbook.SaveAs($path) }

    # same as InsertCell() but does not advance X
    # unsure the use-case, maybe helpful
    [void] InsertCellNoAdvanceX([string]$value) {
        $x = $this.pointerX
        $y = $this.pointerY
        $this.sheet.Cells.Item($x, $y).Value = $value
    }

    #
    # Inserts data into a single cell and advances the X coord
    [void] InsertCell([string]$value) {
        $this.InsertCellNoAdvanceX($value)
        $this.AdvanceX()
    }

    # Adds an entire row to the sheet
    # advances Y and resets X
    [void] AddRow([string[]]$headers) {
        $headers | ForEach-Object {
            $this.InsertCell($_)
        }
        $this.AdvanceY()
    }
}



#
#
#
function Initialize-Excel {
    <#
    .SYNOPSIS
    Creates and initializes a hidden Excel COM automation instance.

    .DESCRIPTION
    Initialize-Excel starts a new instance of Microsoft Excel using COM automation
    and returns the Excel.Application object. The Excel window is created in a
    non‑visible state, allowing scripts to generate or manipulate workbooks
    programmatically without displaying the Excel UI.

    This function is typically used as the first step in Excel automation workflows
    where workbooks, worksheets, or cell data will be created or modified.

    .OUTPUTS
    Microsoft.Office.Interop.Excel.Application
        The Excel COM automation object.

    .EXAMPLE
    $excel = Initialize-Excel
    $workbook = $excel.Workbooks.Add()

    Creates a hidden Excel instance and adds a new workbook.

    .NOTES
    - Requires Microsoft Excel to be installed on the system.
    - Call `$excel.Quit()` when finished to avoid leaving Excel.exe running.
    #>
    
    # Create COM automation object
    $excel = New-Object -ComObject Excel.Application
    # Prevent Excel from opening a visible window
    $excel.Visible = $false
    # Return the Excel application object
    $excel
}

#
#
#
function New-ExcelWorkbook {
    <#
    .SYNOPSIS
    Creates a new Excel workbook using an existing Excel COM instance.

    .DESCRIPTION
    New-ExcelWorkbook creates a new workbook within a running Excel COM automation
    instance and returns an ExcelWorkspace object. The ExcelWorkspace wrapper
    contains the workbook, the first worksheet, and internal cursor pointers used
    for structured cell navigation and writing.

    This function is intended to be used after calling Initialize-Excel, which
    provides the Excel.Application COM object required to create the workbook.

    .PARAMETER Excel
    The Excel.Application COM object returned by Initialize-Excel. This parameter
    accepts pipeline input, allowing the Excel instance to be passed directly
    through the pipeline.

    .OUTPUTS
    ExcelWorkspace
        A strongly typed wrapper containing:
        - The workbook COM object
        - The first worksheet COM object
        - Internal X/Y pointers for cell navigation

    .EXAMPLE
    $excel = Initialize-Excel
    $workspace = New-ExcelWorkbook -Excel $excel

    Creates a new workbook and returns an ExcelWorkspace instance for further
    manipulation.

    .EXAMPLE
    Initialize-Excel | New-ExcelWorkbook

    Demonstrates pipeline support. The Excel COM object produced by Initialize-Excel
    is piped directly into New-ExcelWorkbook, returning an ExcelWorkspace instance.

    .NOTES
    - Requires Microsoft Excel to be installed.
    - Remember to call $excel.Quit() when finished to avoid leaving Excel.exe running.
    #>

    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        [System.__ComObject]$Excel
    )

    # Create a new workbook
    $workbook = $Excel.Workbooks.Add()

    # Return a new ExcelWorkspace instance
    [ExcelWorkspace]::new($workbook, $workbook.Worksheets.Item(1))
}


