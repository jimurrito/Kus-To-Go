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
<#
.SYNOPSIS
    Provides a coordinate‑based writer for Excel COM automation.

.DESCRIPTION
    ExcelWorkspace wraps an Excel workbook and worksheet COM object and exposes
    a simple pointer‑driven API for writing values into cells. The class tracks
    an internal X/Y pointer and provides convenience methods for advancing
    coordinates, inserting values, writing header rows, and saving the workbook.

    This class is intended for sequential, table‑oriented data output where
    rows and columns are written in order.

.NOTES
    Author: James
    Purpose: Lightweight Excel automation helper for structured data export.
#>
class ExcelWorkspace {

    [System.__ComObject]$workbook
    [System.__ComObject]$sheet
    [int]$pointerX
    [int]$pointerY

    <#
    .SYNOPSIS
        Creates a new ExcelWorkspace instance.

    .DESCRIPTION
        Binds the class to an existing Excel workbook and worksheet COM object.
        Initializes the internal pointer to (1,1), matching Excel's 1‑based
        indexing.

    .PARAMETER workbook
        The Excel workbook COM object.

    .PARAMETER sheet
        The Excel worksheet COM object.

    .EXAMPLE
        $ws = [ExcelWorkspace]::new($excel.ActiveWorkbook, $excel.ActiveSheet)
    #>
    ExcelWorkspace([System.__ComObject]$workbook, [System.__ComObject]$sheet) {
        $this.workbook = $workbook
        $this.sheet = $sheet
        $this.pointerX = 1
        $this.pointerY = 1
    }

    <#
    .SYNOPSIS
        Moves the pointer one column to the right.

    .DESCRIPTION
        Increments the X coordinate by 1. Used when writing horizontally.
    #>
    [void] AdvanceX() { $this.pointerX += 1 }

    <#
    .SYNOPSIS
        Moves the pointer down one row and resets X.

    .DESCRIPTION
        Increments the Y coordinate and resets X to 0. This behavior allows
        callers to explicitly set X before writing the next row.
    #>
    [void] AdvanceY() { $this.pointerY += 1; $this.pointerX = 0 }

    <#
    .SYNOPSIS
        Moves the pointer down one row without resetting X.

    .DESCRIPTION
        Useful when writing multi‑column blocks or when X should remain fixed.
    #>
    [void] AdvanceYNoResetX() { $this.pointerY += 1 }

    <#
    .SYNOPSIS
        Saves the workbook to a file.

    .PARAMETER path
        The file path to save the workbook to.

    .EXAMPLE
        $ws.SaveAs("C:\temp\report.xlsx")
    #>
    [void] SaveAs([string]$path) { $this.workbook.SaveAs($path) }

    <#
    .SYNOPSIS
        Writes a value to the current pointer location without advancing X.

    .DESCRIPTION
        Writes the provided value to the cell at (X,Y) but does not modify
        the pointer position.

    .PARAMETER value
        The string value to write into the cell.

    .EXAMPLE
        $ws.InsertCellNoAdvanceX("Hello")
    #>
    [void] InsertCellNoAdvanceX([string]$value) {
        $x = $this.pointerX
        $y = $this.pointerY
        $this.sheet.Cells.Item($x, $y).Value = $value
    }

    <#
    .SYNOPSIS
        Writes a value to the current pointer location and advances X.

    .DESCRIPTION
        Convenience wrapper around InsertCellNoAdvanceX that automatically
        increments the X coordinate after writing.

    .PARAMETER value
        The string value to write.

    .EXAMPLE
        $ws.InsertCell("Name")
    #>
    [void] InsertCell([string]$value) {
        $this.InsertCellNoAdvanceX($value)
        $this.AdvanceX()
    }

    <#
    .SYNOPSIS
        Writes a header row from a list of column names.

    .DESCRIPTION
        Writes each header into the current row, advancing X after each one.
        After writing all headers, advances Y to begin writing data rows.

    .PARAMETER headers
        An array of header names to write.

    .EXAMPLE
        $ws.AddHeader(@("Name","Age","City"))
    #>
    [void] AddHeader([string[]]$headers) {
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


