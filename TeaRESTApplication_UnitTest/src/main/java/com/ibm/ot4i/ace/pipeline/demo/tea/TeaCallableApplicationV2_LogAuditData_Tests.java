package com.ibm.ot4i.ace.pipeline.demo.tea;

import java.io.InputStream;
import java.nio.charset.StandardCharsets;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;

import com.ibm.integration.test.v1.NodeSpy;
import com.ibm.integration.test.v1.SpyObjectReference;
import com.ibm.integration.test.v1.TestMessageAssembly;
import com.ibm.integration.test.v1.TestSetup;
import com.ibm.integration.test.v1.exception.TestException;

import static com.ibm.integration.test.v1.Matchers.*;
import static net.javacrumbs.jsonunit.JsonMatchers.jsonEquals;
import static org.hamcrest.MatcherAssert.assertThat;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertThrows;
import static org.junit.Assert.assertTrue;

public class TeaCallableApplicationV2_LogAuditData_Tests {

	/*
	 * TeaRESTApplication_getIndex_subflow_0001_Test
	 * Test generated by IBM App Connect Enterprise Toolkit 12.0.1.0 on 10-Jun-2021 12:48:56
	 */

	@AfterEach
	public void cleanupTest() throws TestException {
		// Ensure any mocks created by a test are cleared after the test runs 
		TestSetup.restoreAllMocks();
	}

	@Test
    public void TeaCallableApplicationV2_LogAuditData_CreateXML_Test() throws TestException {

            // Define the SpyObjectReference
            SpyObjectReference nodeReference = new SpyObjectReference().application("TeaCallableApplicationV2")
                            .messageFlow("getIndex").subflowNode("getIndexImpl").subflowNode("LogAuditData").node("Create XML from JSON");

            // Initialise a NodeSpy
            NodeSpy nodeSpy = new NodeSpy(nodeReference);

            // Declare a new TestMessageAssembly object for the message being sent into the node
            TestMessageAssembly inputMessageAssembly = new TestMessageAssembly();

            InputStream inputMessage = Thread.currentThread().getContextClassLoader().getResourceAsStream("createXMLFromJSONinputMessage.mxml");
            inputMessageAssembly.buildFromRecordedMessageAssembly(inputMessage);

            // Call the message flow node with the Message Assembly
            nodeSpy.evaluate(inputMessageAssembly, true, "in");

            // Assert the terminal propagate count for the message
            assertThat(nodeSpy, terminalPropagateCountIs("out", 1));

            /* Compare Output Message 1 at output terminal out */
            TestMessageAssembly actualMessageAssembly = nodeSpy.propagatedMessageAssembly("out", 1);

            assertEquals("Earl Grey", actualMessageAssembly.messagePath("XMLNSC.logData.info.name").getStringValue());
    }
	@Test
    public void TeaCallableApplicationV2_LogAuditData_RemoveXML_Test() throws TestException {

            // Define the SpyObjectReference
            SpyObjectReference nodeReference = new SpyObjectReference().application("TeaCallableApplicationV2")
                            .messageFlow("getIndex").subflowNode("getIndexImpl").subflowNode("LogAuditData").node("Remove XML");

            // Initialise a NodeSpy
            NodeSpy nodeSpy = new NodeSpy(nodeReference);

            // Declare a new TestMessageAssembly object for the message being sent into the node
            TestMessageAssembly inputMessageAssembly = new TestMessageAssembly();

            inputMessageAssembly.messagePath("JSON.Data.id").setValue(123);
            inputMessageAssembly.messagePath("JSON.Data.name").setValue("Earl Grey");
            inputMessageAssembly.messagePath("XMLNSC.logData.info.id").setValue(123);
            inputMessageAssembly.messagePath("XMLNSC.logData.info.name").setValue("Earl Grey");

            // Call the message flow node with the Message Assembly
            nodeSpy.evaluate(inputMessageAssembly, true, "in");

            // Assert the terminal propagate count for the message
            assertThat(nodeSpy, terminalPropagateCountIs("out", 1));

            /* Compare Output Message 1 at output terminal out */
            TestMessageAssembly actualMessageAssembly = nodeSpy.propagatedMessageAssembly("out", 1);

            // Make sure the JSON still exists
            assertEquals("Earl Grey", actualMessageAssembly.messagePath("JSON.Data.name").getStringValue());
            // And that XMLNSC does not
            Exception exception = assertThrows(TestException.class, () -> {
            	actualMessageAssembly.messagePath("XMLNSC.logData.info.name").getValueAsString();
            });
            assertTrue(exception.getMessage().contains("Child element does not exist"));
    }

}
