// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0
import React from 'react';
import PropTypes from 'prop-types';
import { Box, Container, Header } from '@cloudscape-design/components';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import rehypeRaw from 'rehype-raw';

// Custom heading components with stronger inline styles
const H1Component = ({ children }) => (
  <h1
    style={{
      fontSize: '1.75em',
      fontWeight: 'bold',
      color: '#232f3e',
      marginTop: '0.5em',
      marginBottom: '0.5em',
      lineHeight: '1.2',
    }}
  >
    {children}
  </h1>
);

const H2Component = ({ children }) => (
  <h2
    style={{
      fontSize: '1.5em',
      fontWeight: 'bold',
      color: '#232f3e',
      marginTop: '0.75em',
      marginBottom: '0.5em',
      lineHeight: '1.3',
    }}
  >
    {children}
  </h2>
);

const H3Component = ({ children }) => (
  <h3
    style={{
      fontSize: '1.25em',
      fontWeight: 'bold',
      color: '#232f3e',
      marginTop: '0.75em',
      marginBottom: '0.5em',
      lineHeight: '1.3',
    }}
  >
    {children}
  </h3>
);

const H4Component = ({ children }) => (
  <h4
    style={{
      fontSize: '1.1em',
      fontWeight: 'bold',
      color: '#232f3e',
      marginTop: '0.75em',
      marginBottom: '0.5em',
      lineHeight: '1.3',
    }}
  >
    {children}
  </h4>
);

const ParagraphComponent = ({ children }) => (
  <p
    style={{
      marginBottom: '1em',
      lineHeight: '1.6',
      color: '#16191f',
    }}
  >
    {children}
  </p>
);

const CodeComponent = ({ inline = false, children }) => {
  if (inline) {
    return (
      <code
        style={{
          backgroundColor: '#f4f4f4',
          padding: '0.2em 0.4em',
          borderRadius: '3px',
          fontFamily: 'Monaco, Consolas, "Courier New", monospace',
          fontSize: '0.9em',
          color: '#d63384',
        }}
      >
        {children}
      </code>
    );
  }
  return (
    <code
      style={{
        fontFamily: 'Monaco, Consolas, "Courier New", monospace',
        fontSize: '0.9em',
      }}
    >
      {children}
    </code>
  );
};

const PreComponent = ({ children }) => (
  <pre
    style={{
      backgroundColor: '#f8f9fa',
      border: '1px solid #e9ecef',
      padding: '1em',
      borderRadius: '5px',
      overflow: 'auto',
      marginBottom: '1em',
      fontFamily: 'Monaco, Consolas, "Courier New", monospace',
      fontSize: '0.9em',
    }}
  >
    {children}
  </pre>
);

const UlComponent = ({ children }) => <ul style={{ marginBottom: '1em', paddingLeft: '2em' }}>{children}</ul>;

const OlComponent = ({ children }) => <ol style={{ marginBottom: '1em', paddingLeft: '2em' }}>{children}</ol>;

const LiComponent = ({ children }) => <li style={{ marginBottom: '0.25em' }}>{children}</li>;

const BlockquoteComponent = ({ children }) => (
  <blockquote
    style={{
      borderLeft: '4px solid #0073bb',
      paddingLeft: '1em',
      marginLeft: '0',
      marginBottom: '1em',
      fontStyle: 'italic',
      color: '#5f6368',
    }}
  >
    {children}
  </blockquote>
);

const TableComponent = ({ children }) => (
  <table
    style={{
      borderCollapse: 'collapse',
      width: '100%',
      marginBottom: '1em',
      border: '1px solid #ddd',
    }}
  >
    {children}
  </table>
);

const ThComponent = ({ children }) => (
  <th
    style={{
      border: '1px solid #ddd',
      padding: '0.5em',
      textAlign: 'left',
      backgroundColor: '#f2f2f2',
      fontWeight: 'bold',
    }}
  >
    {children}
  </th>
);

const TdComponent = ({ children }) => (
  <td
    style={{
      border: '1px solid #ddd',
      padding: '0.5em',
      textAlign: 'left',
    }}
  >
    {children}
  </td>
);

const LinkComponent = ({ children, href = '#' }) => (
  <a
    href={href}
    style={{
      color: '#0073bb',
      textDecoration: 'none',
    }}
    onMouseEnter={(e) => {
      e.target.style.textDecoration = 'underline';
    }}
    onMouseLeave={(e) => {
      e.target.style.textDecoration = 'none';
    }}
  >
    {children}
  </a>
);

const StrongComponent = ({ children }) => <strong style={{ fontWeight: 'bold' }}>{children}</strong>;

const EmComponent = ({ children }) => <em style={{ fontStyle: 'italic' }}>{children}</em>;

// PropTypes for all components
H1Component.propTypes = {
  children: PropTypes.node.isRequired,
};

H2Component.propTypes = {
  children: PropTypes.node.isRequired,
};

H3Component.propTypes = {
  children: PropTypes.node.isRequired,
};

H4Component.propTypes = {
  children: PropTypes.node.isRequired,
};

ParagraphComponent.propTypes = {
  children: PropTypes.node.isRequired,
};

CodeComponent.propTypes = {
  inline: PropTypes.bool,
  children: PropTypes.node.isRequired,
};

PreComponent.propTypes = {
  children: PropTypes.node.isRequired,
};

UlComponent.propTypes = {
  children: PropTypes.node.isRequired,
};

OlComponent.propTypes = {
  children: PropTypes.node.isRequired,
};

LiComponent.propTypes = {
  children: PropTypes.node.isRequired,
};

BlockquoteComponent.propTypes = {
  children: PropTypes.node.isRequired,
};

TableComponent.propTypes = {
  children: PropTypes.node.isRequired,
};

ThComponent.propTypes = {
  children: PropTypes.node.isRequired,
};

TdComponent.propTypes = {
  children: PropTypes.node.isRequired,
};

LinkComponent.propTypes = {
  children: PropTypes.node.isRequired,
  href: PropTypes.string,
};

StrongComponent.propTypes = {
  children: PropTypes.node.isRequired,
};

EmComponent.propTypes = {
  children: PropTypes.node.isRequired,
};

const TextDisplay = ({ textData = null }) => {
  if (!textData || !textData.content) {
    return null;
  }

  const markdownComponents = {
    h1: H1Component,
    h2: H2Component,
    h3: H3Component,
    h4: H4Component,
    p: ParagraphComponent,
    code: CodeComponent,
    pre: PreComponent,
    ul: UlComponent,
    ol: OlComponent,
    li: LiComponent,
    blockquote: BlockquoteComponent,
    table: TableComponent,
    th: ThComponent,
    td: TdComponent,
    a: LinkComponent,
    strong: StrongComponent,
    em: EmComponent,
  };

  return (
    <Container header={<Header variant="h3">Text Response</Header>}>
      <Box padding="m">
        <Box variant="div" fontSize="body-m" padding="s" backgroundColor="background-container-content">
          <div style={{ lineHeight: '1.6' }}>
            <ReactMarkdown remarkPlugins={[remarkGfm]} rehypePlugins={[rehypeRaw]} components={markdownComponents}>
              {textData.content}
            </ReactMarkdown>
          </div>
        </Box>
      </Box>
    </Container>
  );
};

TextDisplay.propTypes = {
  textData: PropTypes.shape({
    content: PropTypes.string.isRequired,
    responseType: PropTypes.string,
  }),
};

TextDisplay.propTypes = {
  textData: PropTypes.shape({
    content: PropTypes.string.isRequired,
    responseType: PropTypes.string,
  }),
};

export default TextDisplay;
