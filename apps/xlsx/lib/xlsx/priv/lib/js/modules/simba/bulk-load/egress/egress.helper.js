var bulkLoadHelper = require("../bulk-load.helper");
var curpHelper = require("../curp-generator.helper");

var states = ['AS', 'BC', 'BS', 'CC', 'CS', 'CH', 'CL', 'CM', 'DF', 'DG', 'GT', 'GR', 'HG', 'JC', 'MC', 'MN', 'MS', 'NT', 'NL',
              'OC', 'PL', 'QT', 'QR', 'SP', 'SL', 'SR', 'TC', 'TS', 'TL', 'VZ', 'YN', 'ZS', 'NE' ];

module.exports = {
    validateDoctorCurp :  validateDoctorCurp,
    validatePatientCurp : validatePatientCurp
}

function validateDoctorCurp(doctor) {

    if(doctor.curp === 'XXXX999999XXXXXX99') return;

    if(
        doctor.curp && doctor.curp.length === 18 &&
        doctor.name && doctor.name !== 'XX' &&
        doctor.lastname && doctor.lastname !== 'XX' &&
        doctor.lastname2 && doctor.lastname2 !== 'XX'
    ){

        doctor.curp = doctor.curp.trim().toUpperCase();

        var curpG = curpHelper.generaCurp({
            nombre            : doctor.name,
            apellido_paterno  : doctor.lastname,
            apellido_materno  : doctor.lastname2,
            fecha_nacimiento  : [1, 1, 1990],
            sexo              : 'H',
            estado            : 'DF'
        });

        if (curpG.substring(0,4) !== doctor.curp.substring(0,4)){
            doctor.curp = curpG.substring(0,4) + doctor.curp.substring(4,18);
        }

        while (doctor.curp.includes('Ñ')) doctor.curp = doctor.curp.replace('Ñ','X');

    } else {
        doctor.curp = 'XXXX999999XXXXXX99';
    }

}

function validatePatientCurp(patient) {
    patient = JSON.parse(patient)
    if (!egress.patient.dateofbirth) egress.patient.dateofbirth = new Date(egress.patient.birthdate);
    if (egress.patient.dateofbirth > egress.stay.admission_date) egress.patient.dateofbirth = egress.stay.admission_date;

    if(patient.curp === 'XXXX999999XXXXXX99') return;

    bulkLoadHelper.toInt(patient,['state_of_birth','key']);

    if(
        patient.curp && patient.curp.length === 18 &&
        patient.name && patient.name !== 'XX' &&
        patient.lastname && patient.lastname !== 'XX' &&
        patient.lastname2 && patient.lastname2 !== 'XX' &&
        patient.dateofbirth && patient.gender &&
        patient.gender.key !== 9 && patient.gender.key !== 8 &&
        patient.state_of_birth && patient.state_of_birth.key !== undefined
    ){

        patient.curp = patient.curp.trim().toUpperCase();

        var sDate = new Date(patient.dateofbirth);
        sDate.setMinutes(sDate.getMinutes() + sDate.getTimezoneOffset());
        var gender = patient.gender.key === 1 ? 'H' : 'M';

        var state = '';
        if(patient.state_of_birth.key === '99'){
            state = 'NE';
        } else if(patient.state_of_birth.key === '98'){
            state = 'SI';
        } else if(
            parseInt(patient.state_of_birth.key) >= 5 &&
            parseInt(patient.state_of_birth.key) <= 8
        ){
            patient.curp = 'XXXX999999XXXXXX99';
            return;
        } else {
            if(parseInt(patient.state_of_birth.key) < 33) {
                state = states[parseInt(patient.state_of_birth.key)-1];
            } else {
                patient.curp = 'XXXX999999XXXXXX99';
                return;
            }
        }

        var curpG = curpHelper.generaCurp({
            nombre            : patient.name,
            apellido_paterno  : patient.lastname,
            apellido_materno  : patient.lastname2,
            fecha_nacimiento  : [sDate.getDate(), (sDate.getMonth() +1), sDate.getFullYear()],
            sexo              : gender,
            estado            : state
        });

        if(curpG){
            if (curpG.substring(0,13) !== patient.curp.substring(0,13)){
                patient.curp = curpG.substring(0,13) + patient.curp.substring(13,18);
            }
        } else {
            patient.curp = 'XXXX999999XXXXXX99';
        }

        while (patient.curp.includes('Ñ')) patient.curp = patient.curp.replace('Ñ','X');

    } else {
        patient.curp = 'XXXX999999XXXXXX99';
    }

}
