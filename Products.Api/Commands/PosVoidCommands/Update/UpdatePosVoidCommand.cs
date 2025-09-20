using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;
using System.Windows.Input;

namespace Products.Api.Commands.PosVoidCommands.Update
{
    public class UpdatePosVoidCommand : IRequest<bool>
    {
        public UpdatePosVoidRequest Request { get; set; }
        public UpdatePosVoidCommand(UpdatePosVoidRequest updatePosVoidRequest)
        {
            Request = updatePosVoidRequest;
        }
        public class UpdatePosVoidCommandHandler : IRequestHandler<UpdatePosVoidCommand, bool>
        {
            private readonly PosVoidService _service;

            public UpdatePosVoidCommandHandler(PosVoidService service)
            {
                _service = service;
            }
            public async Task<bool> Handle(UpdatePosVoidCommand command, CancellationToken cancellationToken)
            {
                try
                {
                    return await _service.Update(
                        command.Request.Id,
                        command.Request.VoidedById,
                        command.Request.VoidedByName, 
                        command.Request.VoidedByName);
                }
                catch (Exception)
                {

                    throw;
                }
            }
        }

        // Nested Validator
        public class UpdatePosVoidCommandValidator : AbstractValidator<UpdatePosVoidCommand>
        {
            public UpdatePosVoidCommandValidator()
            {
                RuleFor(c => c.Request.Id).GreaterThan(0);
                RuleFor(c => c.Request.VoidedBy).GreaterThan(0);
                RuleFor(c => c.Request.VoidedByName).NotEmpty();
            }
        }
    }
}