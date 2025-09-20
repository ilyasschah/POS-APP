using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;
using System.Threading;
using System.Threading.Tasks;

namespace Products.Api.Commands.VoidReasonCommads.Update
{
    public class UpdateVoidReasonCommand : IRequest<bool>
    {
        public int Id { get; }
        public UpdateVoidReasonRequest Request { get; }

        public UpdateVoidReasonCommand(int id, UpdateVoidReasonRequest request)
        {
            Id = id;
            Request = request;
        }

        public class UpdateVoidReasonCommandHandler : IRequestHandler<UpdateVoidReasonCommand, bool>
        {
            private readonly VoidReasonService _service;

            public UpdateVoidReasonCommandHandler(VoidReasonService service)
            {
                _service = service;
            }

            public Task<bool> Handle(UpdateVoidReasonCommand command, CancellationToken cancellationToken)
            {
                return _service.Update(command.Id, command.Request);
            }
        }

        public class UpdateVoidReasonCommandValidator : AbstractValidator<UpdateVoidReasonCommand>
        {
            public UpdateVoidReasonCommandValidator()
            {
                RuleFor(c => c.Id).GreaterThan(0);
                RuleFor(c => c.Request.Name).NotEmpty();
            }
        }
    }
}