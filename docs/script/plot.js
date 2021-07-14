var margin  = {top: 10, right: 10, bottom: 10, left: 10},
    padding = {top: 30, right: 30, bottom: 60, left: 60},
    ydomain      = {min: 0, max: 1},
    debug        = false;
var debug = false;
var Xscale;

function removeplot(){
    d3.select("#plot").selectAll("*").remove();
}

function addplot(Estado, margin, padding, ydomain){
    //Custom heights for d3js plot
    var outerHeight  = 0.7*Math.max(document.documentElement['clientHeight'], $('#plot').parent().height(), 600);
        outerWidth   = Math.max($('#plot').parent().width(), 300);
        innerWidth   = outerWidth - margin.left - margin.right,
        innerHeight  = outerHeight - margin.top - margin.bottom,
        width        = innerWidth - padding.left - padding.right,
        height       = innerHeight - padding.top - padding.bottom;

    // Create svg margins
    var outer = d3.select('#plot').append('svg')
        .attr('width', outerWidth)
        .attr('height', outerHeight);

    if(debug){
        outer.append("rect")
        .attr("width", innerWidth)
        .attr("height", innerHeight)
        .attr('fill', "green")
    }

    var inner = outer.append("g")
                .attr("transform", "translate(" + padding.left + "," + padding.top + ")");

    if(debug){
        inner.append("rect")
        .attr("width", width)
        .attr("height", height)
        .attr('fill', "blue");
    };
    
    
    var parseDate = d3.timeParse("%Y-%m-%d");
    d3.csv("data/Predichos.csv", function(d) {
        d.Fecha = parseDate(d.Fecha);
        return d;

    }).then(function(data) {

        //X.axis
        Xscale = d3.scaleTime()
            .domain(d3.extent(data, function(d) { return d.Fecha; }))
            .range([0, width]);

        axisX  = inner.append("g")
            .attr("transform", "translate(" + 0 + "," + height + ")")
            .attr("id","xaxis")
            .style("stroke-width", 2)
            .call(d3.axisBottom(Xscale).tickFormat(d3.timeFormat("%d/%m/%y")))
            .selectAll("text")
            .attr("y", 0)
            .attr("x", -9)
            .attr("dy", ".35em")
            .style('font-family', 'sans-serif')
            .attr("transform", "rotate(-90)")
            .style("text-anchor", "end");

        //Y-axis
        Yscale = d3.scaleLinear()
            .domain([-ydomain.min, ydomain.max])
            .range([height, 0]);

        axisY = inner.append("g")
            .attr("transform", "translate(" + 0 + "," + 0 + ")")
            .attr("id","yaxis")
            .style("stroke-width", 2)
            .call(d3.axisLeft(Yscale));

        //Create X axis label
        if (outerHeight >= 0.7*620){
            outer.append('text')
                .attr('x', innerWidth / 2 )
                .attr('y',  innerHeight + padding.top/2)
                .style('text-anchor', 'middle')
                .style('font-family', 'sans-serif')
                .style("fill", "white")
                .text("Fecha");
        }

        //Create Y axis label
        if (outerWidth >= 500){
            outer.append('text')
                .attr('y', 0)
                .attr('x', 0)
                .attr('transform', 'translate(' + 0 + ',' + innerHeight/2 + ') rotate(-90)')
                .attr('dy', '1em')
                .style('text-anchor', 'middle')
                .style('font-family', 'sans-serif')
                .style("fill", "white")
                .text("Porcentaje de ocupación");
        }
    
        // define the line
        var valueline = d3.line()
            .x(function(d) { return Xscale(d.Fecha); })
            .y(function(d) { return Yscale(d["50%"]); });

        var valuearea99 = d3.area()
            .x(function(d) { return  Xscale(d.Fecha); })
            .y0(function(d) { return Yscale(d["0.5%"]); })
            .y1(function(d) { return Yscale(d["99.5%"]); })

        var valuearea75 = d3.area()
            .x(function(d) { return  Xscale(d.Fecha); })
            .y0(function(d) { return Yscale(d["12.5%"]); })
            .y1(function(d) { return Yscale(d["87.5%"]); })    
            
        // Add the scatterplot
        inner.append("text")
            .attr("x", (width / 2))             
            .attr("y", 0 - (margin.top/2))
            .attr("text-anchor", "middle")  
            .style("font-size", "30px")
            .attr("fill","white") 
            .style("text-decoration", "underline")  
            .text(Estado);

        // Show confidence interval
        inner.append("path")
            .data([data.filter(function(d) { return d.Estado == Estado; }) ])
            .attr("fill", "#1F2D3A")
            .attr("d", valuearea99);  
            
        // Show confidence interval
        inner.append("path")
            .data([data.filter(function(d) { return d.Estado == Estado; }) ])
            .attr("fill", "#2B3E50")
            .attr("d", valuearea75);      

        // Add the valueline path.
        inner.append("path")
            .data([data.filter(function(d) { return d.Estado == Estado; }) ])
            .attr("class", "line")
            .attr("stroke-width", 2)
            .attr("fill", "none")
            .attr("stroke","#DE6A2A")
            .attr("d", valueline);

        // Add the scatterplot
        inner.selectAll("dot")
                .data(data.filter(function(d) { return d.Estado == Estado & d["Hospitalizados (%)"] != "NA"; }))
                .enter().append("circle")
                .attr("fill", "#ABB6C2")
                .attr("r", 2)
                .attr("cx", function(d) { return Xscale(d.Fecha); })
                .attr("cy", function(d) { return Yscale(d["Hospitalizados (%)"]); }); 
        
        //30 days from now
        var future = new Date();
        future.setDate(future.getDate() + 30);
        inner.append("line")
                .style("stroke-dasharray", ("3, 3"))
                .attr("class", "line")
                .attr("stroke-width", 4)
                .attr("stroke","white")
                .attr("x1", Xscale(future))
                .attr("y1", Yscale(1.00))
                .attr("x2", Xscale(future))
                .attr("y2", Yscale(0.00));
                    
                    
        // Handmade legend
        if (outerHeight >= 0.7*620 & outerWidth >= 500){
            inner.append("circle").attr("cx", 50).attr("cy",Yscale(0.97)).attr("r", 6).style("fill", "#ABB6C2")
            inner.append("circle").attr("cx", 50).attr("cy",Yscale(0.94)).attr("r", 6).style("fill", "#DE6A2A")
            inner.append("circle").attr("cx", 50).attr("cy",Yscale(0.91)).attr("r", 6).style("fill", "#2B3E50")
            inner.append("circle").attr("cx", 50).attr("cy",Yscale(0.88)).attr("r", 6).style("fill", "#1F2D3A")
            inner.append("text").attr("x", 60).attr("y", Yscale(0.96)).text("Datos").style("font-size", "12px").attr("alignment-baseline","middle").attr("fill","white");
            inner.append("text").attr("x", 60).attr("y", Yscale(0.93)).text("Estimación").style("font-size", "12px").attr("alignment-baseline","middle").attr("fill","white");
            inner.append("text").attr("x", 60).attr("y", Yscale(0.90)).text("Escenario 50%").style("font-size", "12px").attr("alignment-baseline","middle").attr("fill","white");
            inner.append("text").attr("x", 60).attr("y", Yscale(0.87)).text("Escenario 90%").style("font-size", "12px").attr("alignment-baseline","middle").attr("fill","white");
        }

    });   
}; 




