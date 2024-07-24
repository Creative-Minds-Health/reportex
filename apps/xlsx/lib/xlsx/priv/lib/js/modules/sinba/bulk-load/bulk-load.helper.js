
module.exports = {
    toInt :  toInt,
    sinbaDate : sinbaDate,
    fixAge : fixAge,
    joinTitles : joinTitles
}

function joinTitles(titles) {
    var titlesS = "";
    for (var i = 0; i < titles.length; i++) {
        titlesS += titles[i] + (i === (titles.length-1) ? '\n' : '|');
    }
    return titlesS;
}

function sinbaDate(date) {
    date = JSON.parse(date)
    date = date.date;
    if(!(date instanceof Date)) date = new Date(date);
    var sDate = new Date(date.getTime());
    sDate.setMinutes(sDate.getMinutes() + sDate.getTimezoneOffset());
    var month = sDate.getMonth() +1;
    var day = sDate.getDate();
    return {"date" : ((day < 10 ? '0' : '') + day) + "/" + ((month < 10 ? '0' : '') + month) + "/" + sDate.getFullYear()}
}

function toInt(data,arrayPath) {
    var currentObject = data;
    for (var i = 0; i <  arrayPath.length; i++) {
        if(currentObject[arrayPath[i]]){
            if(i === (arrayPath.length-1)){
                if(!isNaN(currentObject[arrayPath[i]])){
                    currentObject[arrayPath[i]] = parseInt(currentObject[arrayPath[i]]);
                }
            } else {
                if(Array.isArray(currentObject[arrayPath[i]])){
                    var array = currentObject[arrayPath[i]];
                    for (var x = 0; x < array.length; x++) {
                        fixList(array[x],arrayPath.slice(i+1,arrayPath.length))
                    }
                } else {
                    currentObject = currentObject[arrayPath[i]];
                }
            }
        }
    }
}

function fixAge(patient,consultationDate) {

    if(!patient.dateofbirth) patient.dateofbirth = new Date(patient.birthdate);

    var ret = {
        years : 0,
        months : 0,
        days : 0
    };

    if(patient.dateofbirth > consultationDate) patient.dateofbirth = consultationDate;

    var dt1 = new Date(patient.dateofbirth.getTime());
    var dt2 = new Date(consultationDate.getTime());

    dt1.setMinutes(dt1.getMinutes() + dt1.getTimezoneOffset());
    dt2.setMinutes(dt2.getMinutes() + dt2.getTimezoneOffset());

    dt2.setHours(0);
    dt2.setMinutes(0);
    dt2.setSeconds(0);
    dt2.setMilliseconds(0);


    if(dt1 > dt2) patient.dateofbirth = dt2;
    if(patient.dateofbirth && dt1 != dt2){

        if (dt1 > dt2){
            var dtmp = dt2;
            dt2 = dt1;
            dt1 = dtmp;
        }

        var year1 = dt1.getFullYear();
        var year2 = dt2.getFullYear();

        var month1 = dt1.getMonth();
        var month2 = dt2.getMonth();

        var day1 = dt1.getDate();
        var day2 = dt2.getDate();

        ret.years = year2 - year1;
        ret.months = month2 - month1;
        ret.days = day2 - day1;

        if(year2 == year1 && month2 == (month1+1) && day2 == day1){
            ret.years = 0;
            ret.months = 1;
            ret.days = 0;
        }

        if (ret.days < 0) {

            var dtmp1 = new Date(dt1.getFullYear(), dt1.getMonth() + 1, 1, 0, 0, -1);

            var numDays = dtmp1.getDate();

            ret.months -= 1;
            ret.days += numDays;

        }

        if (ret.months < 0) {
            ret.months += 12;
            ret.years -= 1;
        }

    }

    if(ret.days >= 30) {
    	ret.months++;
        ret.days = 0;
    }

    patient.splited_age = ret;

    return patient;

}
