
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let result = null;

    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error,result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });
    

        // User-submitted transaction
        DOM.elid('status-submit-oracle').addEventListener('click', () => {
            let airline = DOM.elid('status-airline').value;
            let flight = DOM.elid('status-flight').value;
            let timestamp = DOM.elid('status-timestamp').value;

            // Write transaction
            contract.fetchFlightStatus(airline, flight, timestamp, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        })

        DOM.elid('reg-airline-submit').addEventListener('click', () => {
            let airlineAddress = DOM.elid('reg-airline-address').value;
            let airlineName = DOM.elid('reg-airline-name').value;

            // Write transaction
            contract.registerAirline(airlineName,airlineAddress, (error, result) => {
                display('Register Airline', 'Result', [ { label: error ? 'Error': 'Success', error: error, value: error ? 'Failed': 'Success'} ]);
            });
        });

        DOM.elid('insurance-submit').addEventListener('click', () => {
            let airlineAddress = DOM.elid('insurance-airline-address').value;
            let flight = DOM.elid('insurance-flight').value;
            let timestamp = DOM.elid('insurance-flight-timestamp').value;
            let value = DOM.elid('insurance-value').value;


            // Write transaction
            contract.buyInsurance(airlineAddress,flight,timestamp, value, (error, result) => {
                display('Buy Insurance', 'Result', [ { label: error ? 'Error': 'Success', error: error, value: error ? 'Failed': 'Success'} ]);
            });
        });

        DOM.elid('flight-reg-submit').addEventListener('click', () => {
            let airlineAddress = DOM.elid('flight-reg-airline-address').value;
            let flight = DOM.elid('flight-reg-flight').value;
            let timestamp = DOM.elid('flight-reg-timestamp').value;


            // Write transaction
            contract.registerFlight(airlineAddress, flight, timestamp, (error, result) => {
                display('Register flight', 'Result', [ { label: error ? 'Error': 'Success', error: error, value: error ? 'Failed': 'Success'} ]);
            });
        });
        DOM.elid('activate-airline-submit').addEventListener('click', () => {
            let airlineAddress = DOM.elid('activate-airline-address').value;
            let value = DOM.elid('activate-airline-value').value;

            // Write transaction
            contract.submitAirlineFunds(airlineAddress,value, (error, result) => {
                display('Register Airline', 'Activation of airline', [ { label: error ? 'Error': 'Success', error: error, value: error ? 'Failed': ''} ]);
            });
        });


        console.log(JSON.stringify(contract.fetchFlights(), null, 4));
    });
    

})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}







