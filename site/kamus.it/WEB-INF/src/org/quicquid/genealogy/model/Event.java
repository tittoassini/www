/*
 * Created on 26-Dec-2004
*/
package org.quicquid.genealogy.model;

import java.util.Date;


/**
 * @author titto
 */
public interface Event {

    Date getDate();
    
    Place getPlace();
    
    //static Event NOT_HAPPENED = new Event(null,null); 
    
}
