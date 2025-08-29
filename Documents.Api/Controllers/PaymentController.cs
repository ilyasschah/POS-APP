using Documents.Api.Commands.PaymentCommands.Add;
using Documents.Api.Commands.PaymentCommands.Delete;
using Documents.Api.Commands.PaymentCommands.Update;
using Documents.Api.Models;
using Documents.Api.Queries.PaymentQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace Documents.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class PaymentsController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<PaymentDto>>> GetAll()
        {
            return Ok(await mediator.Send(new GetAllPaymentsQuery()));
        }

        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<PaymentDto>> GetById(int id)
        {
            return Ok(await mediator.Send(new GetPaymentByIdQuery { Id = id }));
        }

        //[HttpGet("[action]/ByDocument/{documentId:int}")]
        //public async Task<ActionResult<List<PaymentDto>>> GetByDocumentId(int documentId)
        //{                                                                                             rkia
        //    return Ok(await mediator.Send(new GetPaymentsByDocumentIdQuery (documentId)));
        //}

        [HttpPost("[action]")]
        public async Task<ActionResult<PaymentDto>> Add([FromQuery] CreatePaymentRequest request)
        {
            return Ok(await mediator.Send(new AddPaymentCommand(request)));
        }

        [HttpPost("[action]/{id}")]
        public async Task<IActionResult> Update(int id, [FromQuery] UpdatePaymentRequest request)
        {
            return Ok(await mediator.Send(new UpdatePaymentCommand(id, request)));
        }

        //DELETE: api/payments/delete/5
        [HttpDelete("[action]/{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            return Ok(await mediator.Send(new DeletePaymentCommand { Id = id }));
        }
    }
}