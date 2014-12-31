# ----------------------------------------------------------------------
# Shiny app demonstrating interactive features of the tableFilter widget
# ----------------------------------------------------------------------
library(shiny)
library(htmlwidgets)
library(tableFilter)

data(mtcars);

edits <- data.frame(Row = c("", ""), Column = (c("", "")), Value = (c("", "")), stringsAsFactors = FALSE);
rownames(edits) <- c("Fail", "Success");

filtering <- data.frame(Rows = c(nrow(mtcars), nrow(mtcars)), Indices = c(paste(1:nrow(mtcars), collapse = ', '), paste(1:nrow(mtcars), collapse = ', ')), stringsAsFactors = FALSE);
rownames(filtering) <- c("Before", "After")

shinyServer(function(input, output, session) {
  
  revals <- reactiveValues();
  
  revals$mtcars <- mtcars[ , 1:2];
  revals$edits <- edits;
  revals$filtering <- filtering;
  revals$filters <- NULL;
  revals$rowIndex <- 1:nrow(mtcars);
  revals$filters <- data.frame(Column = character(), Filter = character(), stringsAsFactors = FALSE);
  
  observe({
    if(is.null(input$mtcars_filter)) return(NULL);
    revals$rowIndex <- unlist(input$mtcars_filter$validRows);
    revals$filtering["After", "Rows"] <- length(revals$rowIndex);
    revals$filtering["After", "Indices"] <- paste(revals$rowIndex, collapse = ', ');
    
    filterSettings <-input$mtcars_filter$filterSettings;
    tmp <- lapply(filterSettings, function(x) data.frame(Column = x$column, Filter = x$value, stringsAsFactors = FALSE));
    revals$filters <- do.call("rbind", tmp);
  })
  
  # for a output object "mtcars" tableFilter generates an input
  # "mtcars_edit"
  # this observer does a simple input validation and sends a confirm or reject message after each edit.
  observe({
    if(is.null(input$mtcars_edit)) return(NULL);
     edit <- input$mtcars_edit;
    isolate({
      # need isolate, otherwise this observer would run twice
      # for each edit
      id <- edit$id;
      row <- as.integer(edit$row);
      col <- as.integer(edit$col);
      val <- edit$val;
      
      # validate input 
      if(col > 0) {
        # numeric columns
        if(is.na(suppressWarnings(as.numeric(val)))) {
          oldval <- revals$mtcars[row, col];
          # reset to the old value
          # input will turn red briefly, than fade to previous color while
          # text returns to previous value
          rejectEdit(session, tbl = "mtcars", id = id, value = oldval);
          revals$edits["Fail", "Row"] <- row;
          revals$edits["Fail", "Column"] <- col;
          revals$edits["Fail", "Value"] <- val;
          return(NULL);
        } 
      } else {
        # rownames
        oldval <- rownames(mtcars)[row];
        if(make.names(val) != val) {
          rejectEdit(session, tbl = "mtcars", id = id, value = oldval);
          revals$edits["Fail", "Row"] <- row;
          revals$edits["Fail", "Column"] <- col;
          revals$edits["Fail", "Value"] <- val;
          return(NULL);
        }
      }
      if(col > 0) {
        revals$mtcars[row, col] <- val;
      } else {
        rownames(revals$mtcars)[row] <- val;
      }
      confirmEdit(session, tbl = "mtcars", id = id, value = round(as.numeric(val), 1));
      revals$edits["Success", "Row"] <- row;
      revals$edits["Success", "Column"] <- col;
      revals$edits["Success", "Value"] <- val;
    })
    
   })
  
  output$edits <- renderTable({
    if(is.null(revals$edits)) return(invisible());
    revals$edits;
  });
  
  output$filtering <- renderTable({
    if(is.null(revals$filtering)) return(invisible());
    revals$filtering;
  });

  output$filters <- renderTable({
      if(nrow(revals$filters) == 0) return(invisible());
      revals$filters;
    });
  
  output$filteredMtcars <- renderTable({
      if(is.null(revals$rowIndex)) return(invisible());
      if(is.null(revals$mtcars)) return(invisible());
      revals$mtcars[revals$rowIndex, ];
    });
  
  output$mtcars <- renderTableFilter({
    
    # define table properties. See http://tablefilter.free.fr/doc.php
    # for a complete reference
    tableProps <- list(
      alternate_rows = TRUE,
      btn_reset = TRUE,
      sort = TRUE,
      on_keyup = TRUE,  
      on_keyup_delay = 800,
      sort_config = list(
        # alphabetic sorting for the row names column, numeric for all other columns
        sort_types = c("String", rep("Number", ncol(mtcars)))
      )
    );
    
    # columns are addressed in TableFilter as col_0, col_1, ..., coln
    # the "auto" scales recalculate the data range after each edit
    # to get the same behaviour with manually defined colour scales
    # you can use the "colMin", "colMax", or "colExtent" functions,
    # e.g .domain(colExtent("col_1")) or .domain([0, colMax(col_1)])
    bgColScales <- list(
      col_1 = "auto:white:green",
      col_2 = JS('function colorScale(tbl, i){
        var color = d3.scale.linear()
        .domain([0, colMax(tbl, "col_2")])
        .range(["white", "orangered"])
        .interpolate(d3.interpolateHcl);
        return color(i);
      }')
    );

    tableFilter(mtcars[ , 1:2], tableProps, showRowNames = TRUE,
                rowNamesColumn = "Model", edit = c("col_1", "col_2"),
                bgColScales = bgColScales, filterInput = TRUE);
  })
  
  observe({
    if(input$editing) {
      enableEdit(session, "mtcars");
    } else {
      disableEdit(session, "mtcars");
    }
  })
  
  observe({
    if(input$editingCol0) {
      enableEdit(session, "mtcars", "col_0");
    } else {
      disableEdit(session, "mtcars", "col_0");
    }
  })
  
  output$iris <- renderTableFilter({
    
    # define table properties. See http://tablefilter.free.fr/doc.php
    # for a complete reference
    tableProps <- list(
      alternate_rows = TRUE,
      btn_reset = TRUE,
      sort = FALSE,
      on_keyup = TRUE,  
      on_keyup_delay = 800
    );
    bgColScales <- list(
      col_0 = "auto:white:green",
      col_1 = "auto:blue:red"
    )
    tableFilter(iris[1:10 , 1:2], tableProps, showRowNames = FALSE,
                bgColScales = bgColScales,
                edit = TRUE,
                filterInput = TRUE);
  })
  
  # for a output object "iris" tableFilter generates an input
  # "iris_edit". dont use the values
  observe({
    if(is.null(input$iris_edit)) return(NULL);
    edit <- input$iris_edit;
    id <- edit$id;
    row <- as.integer(edit$row);
    col <- as.integer(edit$col);
    val <- edit$val;
    
    # validate input 
    if(is.na(suppressWarnings(as.numeric(val)))) {
      oldval <- iris[row, col];
      # reset to the old value
      # input will turn red briefly, than fade to previous color while
      # text returns to previous value
      rejectEdit(session, tbl = "iris", id = id);
      return(NULL);
    }
    confirmEdit(session, tbl = "iris", id = id);
    
  })
  
})